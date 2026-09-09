import Foundation

/// The quiet streak: consecutive met days, still alive if today simply
/// hasn't happened yet. No fire, no guilt — a broken streak just starts
/// again at one. Mirrors Android Streak.kt.
enum Streak {

    static func count(metDays: [String], today: Date = Date()) -> Int {
        let met = Set(metDays)
        let calendar = Calendar.current
        var day = met.contains(AffirmationRepository.dayKey(today))
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var run = 0
        while met.contains(AffirmationRepository.dayKey(day)) {
            run += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return run
    }

    static func metToday(metDays: [String], today: Date = Date()) -> Bool {
        metDays.contains(AffirmationRepository.dayKey(today))
    }

    /// Last seven days, oldest first, paired with met/mood for the summary.
    static func week(
        metDays: [String],
        moodLog: [String],
        today: Date = Date()
    ) -> [DaySummary] {
        let met = Set(metDays)
        let calendar = Calendar.current
        return (0..<7).map { offset in
            let back = 6 - offset
            let date = calendar.date(byAdding: .day, value: -back, to: today) ?? today
            let key = AffirmationRepository.dayKey(date)
            return DaySummary(
                date: key,
                met: met.contains(key),
                mood: moodLog
                    .first { $0.split(separator: "|").first.map(String.init) == key }?
                    .split(separator: "|").last.map(String.init)
            )
        }
    }

    struct DaySummary: Hashable {
        let date: String
        let met: Bool
        let mood: String?
    }
}
