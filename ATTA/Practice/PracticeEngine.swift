import AVFoundation
import Combine
import Foundation

/// An ambient bed for Practice. None keeps the room silent.
/// Mirrors the Android `Moods` list (MoodPlayer.kt) one-for-one.
struct PracticeMood: Identifiable, Hashable {
    let id: String
    let displayName: String
    /// Bundled wav basename, nil for silence.
    let resource: String?
}

enum Moods {
    static let none = PracticeMood(id: "none", displayName: "None", resource: nil)
    static let calm = PracticeMood(id: "calm", displayName: "Calm", resource: "mood_calm")
    static let rain = PracticeMood(id: "rain", displayName: "Rain", resource: "mood_rain")
    static let waves = PracticeMood(id: "waves", displayName: "Waves", resource: "mood_waves")
    static let wind = PracticeMood(id: "wind", displayName: "Wind", resource: "mood_wind")
    static let stream = PracticeMood(id: "stream", displayName: "Stream", resource: "mood_stream")
    static let all = [none, calm, rain, waves, wind, stream]

    static func byId(_ id: String?) -> PracticeMood {
        all.first { $0.id == id } ?? calm
    }
}

/// The Practice audio loop: the feed read aloud, one line at a time with quiet
/// gaps, over an optional mood bed. The iOS stand-in for Android's
/// PracticeService + PracticeVoice + MoodPlayer — the screen is a remote, this
/// engine owns the voice, the bed, the line loop, and the sleep timer. With
/// AVAudioSession .playback and the audio background mode, it keeps reading
/// while the phone is locked.
@MainActor
final class PracticeEngine: ObservableObject {

    // MARK: State the screen mirrors (Android PracticeState)

    @Published private(set) var active = false
    @Published private(set) var playing = false
    @Published private(set) var index = 0
    @Published private(set) var voiceUnavailable = false
    @Published private(set) var timerMinutes = 0 // 0 = no sleep timer

    private(set) var source = PracticeEngine.sourceFeed
    private(set) var queue: [Affirmation] = []

    // MARK: Timing — the Android PracticeService constants, ms → seconds.

    private static let preLineGap: Duration = .milliseconds(700)
    private static let lineGap: Duration = .seconds(4)
    private static let silentLine: Duration = .seconds(9)
    private static let fadeSteps = 12
    private static let fadeStep: Duration = .milliseconds(400)

    static let sourceFeed = "feed"
    static let sourceSaved = "saved"

    // MARK: Internals

    private let store: AttaStore
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate = SpeechDelegate()
    private var speechDone: CheckedContinuation<Void, Never>?
    private var moodPlayer: AVAudioPlayer?
    private var currentMoodResource: String?
    private var loopTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var endPending = false
    private var silentLines = 0
    private var settingsCancellable: AnyCancellable?
    private var lastSettings: AttaSettings?

    init(store: AttaStore = .shared) {
        self.store = store
        synthesizer.delegate = speechDelegate
        speechDelegate.onFinish = { [weak self] in
            Task { @MainActor in self?.finishSpeech() }
        }
    }

    /// The one list Practice reads from, built identically by the engine and
    /// the screen (same inputs → same order, no shared state needed).
    /// Mirrors PracticeQueue.build.
    static func buildQueue(
        source: String,
        settings: AttaSettings,
        today: Date = Date(),
        evening: Bool
    ) -> [Affirmation] {
        switch source {
        case sourceSaved:
            return CustomLines.parse(settings.customLines) +
                Affirmations.all.filter { settings.savedIds.contains($0.id) }
        default:
            return AffirmationRepository
                .feed(today: today, days: 30, focusIds: Set(settings.focusIds), evening: evening)
                .map { $0.line }
        }
    }

    static func eveningNow(_ date: Date = Date()) -> Bool {
        Calendar.current.component(.hour, from: date) >= 18
    }

    // MARK: Controls (Android PracticeService actions)

    /// Starts practice at a queue position, or jumps the running session there.
    func start(index startIndex: Int, source: String) {
        // Silence the old reading immediately — a switch must never let the
        // previous queue slip in one more line while the new one spins up.
        loopTask?.cancel()
        stopSpeech()

        self.source = source
        // Always rebuild: focus, saved, and custom lines may have changed
        // since the queue was last cached.
        queue = Self.buildQueue(source: source, settings: store.settings, evening: Self.eveningNow())
        guard !queue.isEmpty else {
            stop()
            return
        }
        index = min(max(startIndex, 0), queue.count - 1)
        active = true
        playing = true
        // Practicing counts as meeting the day's line.
        store.recordMetDay()
        refreshVoiceAvailability()
        activateSession()
        observeSettings()
        runLoop()
    }

    func toggle() {
        playing ? pause() : resume()
    }

    /// Sleep timer: wall-clock; when it fires the mood fades and the session
    /// ends after the line being read. 0 clears it.
    func setTimer(minutes: Int) {
        timerTask?.cancel()
        endPending = false
        timerMinutes = minutes
        guard minutes > 0 else { return }
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled, let self else { return }
            if self.playing {
                self.endPending = true
                for step in 0..<Self.fadeSteps {
                    self.setMoodLevel(1 - Double(step + 1) / Double(Self.fadeSteps))
                    try? await Task.sleep(for: Self.fadeStep)
                    if Task.isCancelled { return }
                }
            } else {
                self.stop()
            }
        }
    }

    /// End the session and release everything (Android end()).
    func stop() {
        loopTask?.cancel()
        loopTask = nil
        timerTask?.cancel()
        timerTask = nil
        endPending = false
        silentLines = 0
        stopSpeech()
        stopMood()
        settingsCancellable = nil
        lastSettings = nil
        active = false
        playing = false
        index = 0
        timerMinutes = 0
        voiceUnavailable = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resume() {
        guard active, !playing else { return }
        playing = true
        activateSession()
        runLoop()
    }

    private func pause() {
        guard playing else { return }
        loopTask?.cancel()
        stopSpeech()
        stopMood()
        playing = false
    }

    // MARK: The line loop (Android runLoop)

    private func runLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            guard let self else { return }
            self.applyMood()
            while !Task.isCancelled {
                guard self.active, self.queue.indices.contains(self.index) else { break }
                let entry = self.queue[self.index]
                let settings = self.store.settings
                if self.voiceUnavailable {
                    // No voice for this language: keep the rhythm in silence
                    // but re-check every couple of lines instead of staying
                    // mute forever (a voice may have finished downloading).
                    try? await Task.sleep(for: Self.silentLine)
                    self.silentLines += 1
                    if self.silentLines % 2 == 0 { self.refreshVoiceAvailability() }
                } else if settings.practicePace == "off" {
                    // Voice switched off: the mood bed and the line rhythm
                    // continue in silence.
                    try? await Task.sleep(for: Self.silentLine)
                } else {
                    try? await Task.sleep(for: Self.preLineGap)
                    if Task.isCancelled { break }
                    await self.speak(
                        entry.text(settings.language),
                        language: settings.language,
                        slow: settings.practicePace != "normal"
                    )
                    try? await Task.sleep(for: Self.lineGap)
                }
                if Task.isCancelled { break }
                if self.endPending {
                    self.stop()
                    break
                }
                self.index = (self.index + 1) % self.queue.count
            }
        }
    }

    // MARK: Voice (Android PracticeVoice)

    /// Reads one line, suspending until the synthesizer finishes it.
    /// Kotlin's 0.72 slow / 0.95 normal TextToSpeech rates map to calm
    /// AVSpeechUtterance rates: slow ≈ 0.42, normal ≈ 0.5. Kotlin sets no
    /// pitch and no pre-utterance delay — the 700ms breath before each line
    /// lives in the loop, as it does on Android.
    private func speak(_ line: String, language: String, slow: Bool) async {
        guard let voice = Self.voice(for: language) else {
            voiceUnavailable = true
            return
        }
        let utterance = AVSpeechUtterance(string: line)
        utterance.voice = voice
        utterance.rate = slow ? 0.42 : 0.5
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                speechDone = continuation
                synthesizer.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in self.stopSpeech() }
        }
    }

    private static func voice(for language: String) -> AVSpeechSynthesisVoice? {
        // Kotlin: Locale th-TH for Thai, Locale.US for English.
        AVSpeechSynthesisVoice(language: language == "th" ? "th-TH" : "en-US")
    }

    /// Missing engine or voice degrades to silent lines — never a crash
    /// (Android PracticeVoice.State.Unavailable).
    private func refreshVoiceAvailability() {
        let available = Self.voice(for: store.settings.language) != nil
        if available { silentLines = 0 }
        voiceUnavailable = !available
    }

    private func stopSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeech()
    }

    private func finishSpeech() {
        let continuation = speechDone
        speechDone = nil
        continuation?.resume()
    }

    /// AVSpeechSynthesizerDelegate needs NSObject; kept out of the engine's
    /// own declaration so the class stays a plain ObservableObject.
    private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
        var onFinish: (() -> Void)?

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onFinish?()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            onFinish?()
        }
    }

    // MARK: Mood bed (Android MoodPlayer)

    /// Loops one bundled mood quietly under the voice — 0.3 of full volume.
    private static let bedVolume: Float = 0.3

    private func applyMood() {
        let settings = store.settings
        let mood = settings.freeTier ? Moods.none : Moods.byId(settings.practiceMood)
        guard playing, let resource = mood.resource else {
            stopMood()
            return
        }
        if resource == currentMoodResource, moodPlayer?.isPlaying == true { return }
        stopMood()
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return }
        player.numberOfLoops = -1
        player.volume = Self.bedVolume
        player.play()
        moodPlayer = player
        currentMoodResource = resource
    }

    /// 0..1 of the bed's own level — the sleep-timer fade walks this down.
    private func setMoodLevel(_ fraction: Double) {
        moodPlayer?.volume = Self.bedVolume * Float(min(max(fraction, 0), 1))
    }

    private func stopMood() {
        moodPlayer?.stop()
        moodPlayer = nil
        currentMoodResource = nil
    }

    // MARK: Session + settings

    private func activateSession() {
        // .playback + UIBackgroundModes audio: practice keeps reading with the
        // screen locked, like Android's foreground media service.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// The queue's inputs can change mid-session: rebuild it so the voice
    /// never keeps reading a stale list (Android's prefs.settings collector).
    private func observeSettings() {
        lastSettings = store.settings
        settingsCancellable = store.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] latest in
                guard let self else { return }
                let previous = self.lastSettings
                self.lastSettings = latest
                if self.active, let previous,
                   previous.focusIds != latest.focusIds ||
                   previous.savedIds != latest.savedIds ||
                   previous.customLines != latest.customLines {
                    self.queue = Self.buildQueue(
                        source: self.source, settings: latest, evening: Self.eveningNow()
                    )
                    if self.queue.isEmpty {
                        self.stop()
                        return
                    }
                    self.index = min(max(self.index, 0), self.queue.count - 1)
                }
                if self.playing { self.applyMood() }
            }
    }
}
