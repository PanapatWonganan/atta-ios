import Foundation
import Combine

/// Mirrors the Android AttaSettings field-for-field so behavior stays in sync.
struct AttaSettings: Codable, Equatable {
    var onboardingDone = false
    var savedIds: [String] = []
    var themeId = WidgetThemes.defaultId
    var focusIds: [String] = []
    var morningHour = 7 // window start for daily-line reminders
    var morningMinute = 0
    var eveningLine = true
    var remindersPerDay = 3 // evenly spaced inside the window
    var windowEndHour = 21
    var windowEndMinute = 0
    var plan = Plans.none
    var appearance = "system" // system | light | dark
    var language = "en" // en | th
    var practiceMood = "calm" // none | calm | rain | waves
    var practicePace = "slow" // slow | normal
    var customLines: [String] = [] // "<id>\u{1}<text>" — see CustomLines
    var moodLog: [String] = [] // "<yyyy-MM-dd>|<calm|okay|heavy>", one per day
    var plusPassUntil: Double = 0 // epoch seconds; rewarded day-pass expiry
    var usageDays: [String] = [] // distinct "yyyy-MM-dd" the app was opened

    /// Free means no paid plan AND no live day pass.
    var freeTier: Bool {
        Plans.isFree(plan) && Date().timeIntervalSince1970 >= plusPassUntil
    }
}

/// The one settings store, persisted as JSON in the shared app-group defaults
/// so the widget reads the same state as the app.
final class AttaStore: ObservableObject {
    static let shared = AttaStore()

    static let appGroup = "group.com.atta.ios"
    private static let key = "atta_settings"

    @Published private(set) var settings: AttaSettings

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Widget-side read: no observation, just the latest snapshot.
    static func snapshot() -> AttaSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AttaSettings.self, from: data)
        else { return AttaSettings() }
        return decoded
    }

    private init() {
        settings = Self.snapshot()
    }

    func update(_ mutate: (inout AttaSettings) -> Void) {
        var next = settings
        mutate(&next)
        guard next != settings else { return }
        settings = next
        if let data = try? JSONEncoder().encode(next) {
            Self.defaults.set(data, forKey: Self.key)
        }
    }

    // Mirrors of the Android AttaPrefs setters.

    func setOnboardingDone() { update { $0.onboardingDone = true } }

    func toggleSaved(_ id: String) {
        update {
            if let i = $0.savedIds.firstIndex(of: id) {
                $0.savedIds.remove(at: i)
            } else {
                $0.savedIds.append(id)
            }
        }
    }

    func setThemeId(_ id: String) { update { $0.themeId = id } }
    func setFocusIds(_ ids: [String]) { update { $0.focusIds = ids } }

    func setMorningTime(hour: Int, minute: Int) {
        update { $0.morningHour = hour; $0.morningMinute = minute }
    }

    func setEveningLine(_ enabled: Bool) { update { $0.eveningLine = enabled } }
    func setRemindersPerDay(_ count: Int) { update { $0.remindersPerDay = count } }

    func setWindowEnd(hour: Int, minute: Int) {
        update { $0.windowEndHour = hour; $0.windowEndMinute = minute }
    }

    func setPlan(_ plan: String) { update { $0.plan = plan } }
    func setAppearance(_ value: String) { update { $0.appearance = value } }
    func setLanguage(_ value: String) { update { $0.language = value } }
    func setPracticeMood(_ value: String) { update { $0.practiceMood = value } }
    func setPracticePace(_ value: String) { update { $0.practicePace = value } }

    func addCustomLine(_ entry: String) { update { $0.customLines.append(entry) } }

    func removeCustomLine(id: String) {
        update {
            $0.customLines.removeAll { $0.split(separator: "\u{1}").first.map(String.init) == id }
        }
    }

    func setPlusPassUntil(_ epochSeconds: Double) { update { $0.plusPassUntil = epochSeconds } }

    /// One entry per distinct day; keeps only the most recent 60.
    func recordUsageDay(_ day: String = AffirmationRepository.dayKey()) {
        update {
            let days = Set($0.usageDays + [day])
            $0.usageDays = Array(days.sorted(by: >).prefix(60))
        }
    }

    /// One entry per day: relogging a day replaces its value.
    func logMood(day: String, value: String) {
        update {
            $0.moodLog.removeAll { $0.split(separator: "|").first.map(String.init) == day }
            $0.moodLog.append("\(day)|\(value)")
        }
    }
}
