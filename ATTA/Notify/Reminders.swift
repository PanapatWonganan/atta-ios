import Foundation
import UserNotifications

/// N reminders a day, evenly spaced inside the user's window. iOS can't vary a
/// repeating trigger's content per day, so we schedule the next 7 days of
/// concrete (date, slot) pairs — the deterministic repository keeps every one
/// in step with the widget and feed — and refresh whenever the app opens.
enum Reminders {

    static let maxSlots = 10
    private static let daysAhead = 7

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(_ settings: AttaSettings) {
        Task { await rescheduleAsync(settings) }
    }

    static func rescheduleAsync(_ settings: AttaSettings) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        center.removeAllPendingNotificationRequests()

        let count = min(max(settings.remindersPerDay, 1), maxSlots)
        let focus = Set(settings.focusIds)
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for slot in 0..<count {
                let time = slotTime(settings, slot: slot)
                var comps = calendar.dateComponents([.year, .month, .day], from: day)
                comps.hour = time.hour
                comps.minute = time.minute
                guard let fireDate = calendar.date(from: comps), fireDate > now else { continue }

                let evening = time.hour >= 18
                let line = AffirmationRepository.lineForSlot(
                    date: fireDate, slot: slot, focusIds: focus, evening: evening
                )
                let content = UNMutableNotificationContent()
                content.title = slot == 0
                    ? tr(settings.language, "Your morning line is ready", "ประโยคยามเช้าของคุณพร้อมแล้ว")
                    : evening
                        ? tr(settings.language, "Your evening line is ready", "ประโยคค่ำคืนของคุณพร้อมแล้ว")
                        : tr(settings.language, "A line for you", "ประโยคสำหรับคุณ")
                content.body = "\u{201C}\(line.text(settings.language).replacingOccurrences(of: "\n", with: " "))\u{201D}"
                content.sound = nil
                content.userInfo = ["lineId": line.id]

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "atta_line_\(dayOffset)_\(slot)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    /// Slot i sits at start + i * span/(count-1); a single slot sits at start.
    static func slotTime(_ settings: AttaSettings, slot: Int) -> (hour: Int, minute: Int) {
        let start = settings.morningHour * 60 + settings.morningMinute
        let end = settings.windowEndHour * 60 + settings.windowEndMinute
        let count = min(max(settings.remindersPerDay, 1), maxSlots)
        let span = max(end - start, 0)
        let minutes = count == 1 ? start : start + slot * span / (count - 1)
        return (min(max(minutes / 60, 0), 23), min(max(minutes % 60, 0), 59))
    }
}
