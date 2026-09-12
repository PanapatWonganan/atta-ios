import SwiftUI

/// Practice: the feed read aloud, one line at a time with quiet gaps, over an
/// optional mood bed. The audio lives in [PracticeEngine]; this screen is the
/// remote. Port of Android PracticeScreen.kt.
struct PracticeScreen: View {
    let source: String
    let startIndex: Int

    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors
    @StateObject private var engine = PracticeEngine()

    @State private var showMoods = false
    @State private var showCheckIn = false
    @State private var started = false

    private var todayKey: String { AffirmationRepository.dayKey() }

    private var feed: [Affirmation] {
        PracticeEngine.buildQueue(
            source: source,
            settings: store.settings,
            evening: PracticeEngine.eveningNow()
        )
    }

    private var freeTier: Bool { store.settings.freeTier }

    private var theme: WidgetTheme {
        WidgetThemes.byId(freeTier ? WidgetThemes.freeThemeId : store.settings.themeId)
    }

    private var mood: PracticeMood {
        freeTier ? Moods.none : Moods.byId(store.settings.practiceMood)
    }

    private var loggedToday: Bool {
        store.settings.moodLog.contains {
            $0.split(separator: "|").first.map(String.init) == todayKey
        }
    }

    var body: some View {
        if feed.isEmpty {
            Color.clear.onAppear { router.pop() }
        } else {
            content
        }
    }

    /// Android shows an AdMob interstitial on close for the free tier — OMITTED
    /// on iOS v1 (no AdMob). The check-in sheet is the only close gate.
    private func close() {
        if loggedToday { finish() } else { showCheckIn = true }
    }

    private func finish() {
        engine.stop()
        router.pop()
    }

    private var content: some View {
        let index = min(max(engine.index, 0), feed.count - 1)
        return ZStack {
            GeometryReader { geo in
                theme.gradient(in: geo.size)
            }
            .ignoresSafeArea()
            Color.black.opacity(0.30)
                .ignoresSafeArea()
            // The living layer: pools of light breathing under the practice text.
            LivingBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                // Kotlin: Spacer(weight = 1f) above the line, 1.2f below —
                // equal-share SwiftUI Spacers in a 5:6 count give the ratio.
                ForEach(0..<5, id: \.self) { _ in Spacer(minLength: 0) }
                ZStack {
                    Text(feed[index].text(store.settings.language))
                        .atta(.displaySm, theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .id(index)
                        .transition(.opacity)
                }
                .animation(AttaMotion.ease(0.9), value: index)
                Spacer().frame(height: 34)
                BreathingRule(theme: theme, breathing: engine.playing)
                ForEach(0..<6, id: \.self) { _ in Spacer(minLength: 0) }
                Image(systemName: "chevron.up")
                    .font(.system(size: 15, weight: .ultraLight))
                    .foregroundStyle(theme.ink.opacity(0.3))
                Spacer().frame(height: 20)
                paceRow
                Spacer().frame(height: 22)
                playButton
                bottomStatus
            }
            .padding(.horizontal, AttaDimens.md)
        }
        // Swipe up for the next line, down for the previous one — the engine
        // jumps there and keeps reading.
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 110
                    let current = engine.index
                    if value.translation.height < -threshold {
                        engine.start(index: (current + 1) % feed.count, source: source)
                    } else if value.translation.height > threshold {
                        engine.start(index: (current - 1 + feed.count) % feed.count, source: source)
                    }
                }
        )
        .onAppear {
            guard !started else { return }
            started = true
            engine.start(index: startIndex, source: source)
        }
        .sheet(isPresented: $showCheckIn, onDismiss: finish) {
            CheckInSheet(
                moodLog: store.settings.moodLog,
                today: Date(),
                onPick: { value in
                    // Android also logs analytics and, on "calm", asks
                    // ReviewPrompter for an in-app review — out of this slice.
                    store.logMood(day: AffirmationRepository.dayKey(), value: value)
                    // Checking in counts as meeting the day's line.
                    store.recordMetDay(AffirmationRepository.dayKey())
                    showCheckIn = false
                }
            )
        }
        .sheet(isPresented: $showMoods) {
            MoodSheet(
                selectedId: mood.id,
                freeTier: freeTier,
                onPick: { picked in
                    store.setPracticeMood(picked)
                    showMoods = false
                },
                onRequireUpgrade: {
                    showMoods = false
                    router.push(.paywall(source: "upgrade"))
                }
            )
        }
    }

    private var header: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .ultraLight))
                    .foregroundStyle(theme.ink.opacity(0.55))
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close practice")

            Spacer()

            Button { showMoods = true } label: {
                // The free tier hears silence — say what's behind the chip
                // instead of a dead-looking "None".
                Text(freeTier ? "Sound · Plus" : mood.displayName)
                    .font(AttaType.sans(11, .medium))
                    .tracking(0.3)
                    .foregroundStyle(theme.ink.opacity(0.75))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(theme.ink.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            // Sleep timer: taps cycle off → 5 → 10 → 15 minutes.
            Button {
                let next: Int = switch engine.timerMinutes {
                case 0: 5
                case 5: 10
                case 10: 15
                default: 0
                }
                engine.setTimer(minutes: next)
            } label: {
                Text(engine.timerMinutes == 0 ? "∞" : "\(engine.timerMinutes)′")
                    .font(AttaType.sans(12, .medium))
                    .foregroundStyle(
                        engine.timerMinutes == 0
                            ? theme.ink.opacity(0.45)
                            : AttaPalette.champagne
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                engine.timerMinutes == 0
                    ? "Sleep timer, off"
                    : "Sleep timer, \(engine.timerMinutes) minutes"
            )
        }
        .padding(.top, 18)
    }

    private var paceRow: some View {
        HStack(spacing: 26) {
            ForEach([("off", "VOICE OFF"), ("slow", "SLOW"), ("normal", "NORMAL")], id: \.0) { id, label in
                let pace = store.settings.practicePace
                let selected = pace == id || (id == "slow" && pace != "off" && pace != "normal")
                Button { store.setPracticePace(id) } label: {
                    Text(label)
                        .font(AttaType.sans(10, .medium))
                        .tracking(1.8)
                        .foregroundStyle(selected ? AttaPalette.champagne : theme.ink.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var playButton: some View {
        Button { engine.toggle() } label: {
            ZStack {
                Circle().stroke(theme.ink.opacity(0.28), lineWidth: 1)
                Image(systemName: engine.playing ? "pause" : "play")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(theme.ink)
            }
            .frame(width: 76, height: 76)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.playing ? "Pause" : "Play")
    }

    private var bottomStatus: some View {
        ZStack {
            if engine.voiceUnavailable {
                Text("Voice unavailable on this device")
                    .atta(.caption, theme.ink.opacity(0.45))
            } else {
                Spacer().frame(height: 18)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
    }
}

/// The breath is the only motion on screen: a hairline that widens for 4s in
/// and settles for 6s out (atta.motion.breath), matching a slow exhale-heavy
/// rhythm. Paused practice holds it still.
private struct BreathingRule: View {
    let theme: WidgetTheme
    let breathing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !breathing)) { context in
            let cycle = AttaMotion.breathIn + AttaMotion.breathOut
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            let inFraction = AttaMotion.breathIn / cycle
            let breath: Double = !breathing
                ? 0
                : phase < inFraction
                    ? easeInOut(phase / inFraction)
                    : 1 - easeInOut((phase - inFraction) / (1 - inFraction))
            Rectangle()
                .fill(theme.ink.opacity(0.25 + 0.3 * breath))
                .frame(width: 26 + 34 * breath, height: 1)
        }
        .frame(height: 1)
    }

    /// AttaMotion's 0.42/0/0.58/1 curve in closed form — sinusoidal ease,
    /// visually identical at hairline scale.
    private func easeInOut(_ t: Double) -> Double {
        0.5 - cos(.pi * min(max(t, 0), 1)) / 2
    }
}

/// The quiet check-in shown once a day when leaving practice: one tap, three
/// words, and a fortnight of small dots. No streaks, no numbers.
private struct CheckInSheet: View {
    @Environment(\.atta) private var colors
    let moodLog: [String]
    let today: Date
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How do you feel?")
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
                .padding(.bottom, 10)
            ForEach([("calm", "Calm"), ("okay", "Okay"), ("heavy", "Heavy")], id: \.0) { key, label in
                Button { onPick(key) } label: {
                    Text(label)
                        .font(AttaType.serif(19))
                        .foregroundStyle(colors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 13)
                        .padding(.horizontal, 4)
                        .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusChip))
                }
                .buttonStyle(TapScaleStyle())
            }
            Spacer().frame(height: 18)
            HStack(spacing: 9) {
                ForEach(0..<14, id: \.self) { slot in
                    let back = 13 - slot
                    let date = Calendar.current.date(byAdding: .day, value: -back, to: today) ?? today
                    let key = AffirmationRepository.dayKey(date)
                    let value = moodLog
                        .first { $0.split(separator: "|").first.map(String.init) == key }?
                        .split(separator: "|").last.map(String.init)
                    Circle()
                        .fill(dotColor(value))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 4)
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.height(320)])
        .presentationBackground(colors.canvas)
        .presentationDragIndicator(.visible)
    }

    private func dotColor(_ value: String?) -> Color {
        switch value {
        case "calm": AttaPalette.champagne
        case "okay": colors.inkAlpha(0.3)
        case "heavy": colors.inkAlpha(0.65)
        default: colors.inkAlpha(0.08)
        }
    }
}

/// Mood picker. On the free tier only silence stays unlocked — quietly.
private struct MoodSheet: View {
    @Environment(\.atta) private var colors
    @Environment(\.dismiss) private var dismiss
    let selectedId: String
    let freeTier: Bool
    let onPick: (String) -> Void
    let onRequireUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mood")
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
                .padding(.bottom, 10)
            ForEach(Moods.all) { mood in
                let locked = freeTier && mood.id != Moods.none.id
                Button {
                    if locked { onRequireUpgrade() } else { onPick(mood.id) }
                } label: {
                    HStack {
                        Text(mood.displayName)
                            .font(AttaType.sans(15))
                            .foregroundStyle(colors.ink)
                        Spacer()
                        if mood.id == selectedId {
                            Text("IN USE")
                                .font(AttaType.sans(9, .medium))
                                .tracking(1.2)
                                .foregroundStyle(AttaPalette.champagneDeep)
                        } else if locked {
                            Text("Unlock")
                                .font(AttaType.sans(11))
                                .tracking(0.5)
                                .foregroundStyle(AttaPalette.champagneDeep)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 13)
                    .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusChip))
                }
                .buttonStyle(TapScaleStyle())
            }
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.height(400)])
        .presentationBackground(colors.canvas)
        .presentationDragIndicator(.visible)
    }
}
