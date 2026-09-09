import Foundation

/// Deterministic line-of-day selection: the same date, focus set, and daypart
/// always produce the same line, so the widget, notification, and home feed
/// agree without any shared mutable state.
enum AffirmationRepository {

    /// Days since epoch in the user's calendar — the iOS stand-in for
    /// LocalDate.toEpochDay(), and it must stay deterministic across processes.
    static func epochDay(_ date: Date) -> Int {
        Int((Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400).rounded(.down))
    }

    static func lineFor(
        date: Date,
        focusIds: Set<String> = [],
        evening: Bool = false
    ) -> Affirmation {
        let pool = Affirmations.all.filter {
            evening ? $0.daypart != .morning : $0.daypart != .night
        }
        let focused = pool.filter { focusIds.contains($0.categoryId) }
        let candidates = focused.isEmpty ? pool : focused
        let idx = mod(epochDay(date) + (evening ? 1 : 0), candidates.count)
        return candidates[idx]
    }

    /// A distinct line per reminder slot within a day. Deterministic, so a
    /// rescheduled notification repeats its own line instead of drifting.
    static func lineForSlot(
        date: Date,
        slot: Int,
        focusIds: Set<String> = [],
        evening: Bool = false
    ) -> Affirmation {
        let pool = Affirmations.all.filter {
            evening ? $0.daypart != .morning : $0.daypart != .night
        }
        let focused = pool.filter { focusIds.contains($0.categoryId) }
        let candidates = focused.isEmpty ? pool : focused
        let idx = mod(epochDay(date) * 7 + slot, candidates.count)
        return candidates[idx]
    }

    /// Home feed: today first, then one line per previous day.
    static func feed(
        today: Date,
        days: Int,
        focusIds: Set<String> = [],
        evening: Bool = false
    ) -> [(date: Date, line: Affirmation)] {
        (0..<days).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            return (date, lineFor(date: date, focusIds: focusIds, evening: evening && offset == 0))
        }
    }

    private static func mod(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r >= 0 ? r : r + n
    }

    private static func locale(_ lang: String) -> Locale {
        lang == "th" ? Locale(identifier: "th_TH") : Locale(identifier: "en_US")
    }

    /// "1 Sep" — the widget/card date stamp.
    static func shortDate(_ date: Date, lang: String = "en") -> String {
        let f = DateFormatter()
        f.locale = locale(lang)
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    /// "Monday, 1 September" — lock screen and home header.
    static func longDate(_ date: Date, lang: String = "en") -> String {
        let f = DateFormatter()
        f.locale = locale(lang)
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: date)
    }

    /// "yyyy-MM-dd" key used by the mood log and usage-day tracking.
    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
