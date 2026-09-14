import SwiftUI

/// The streak, made visible: the run count in a ring and this week's seven
/// days, met ones filled champagne. Quiet arithmetic of showing up — no
/// fire, no guilt; a missed day just starts the count again.
/// Mirrors Android StreakCard.kt.
struct StreakCard: View {
    @Environment(\.atta) private var colors
    let settings: AttaSettings

    var body: some View {
        let lang = settings.language
        let today = Date()
        let todayKey = AffirmationRepository.dayKey(today)
        let streak = Streak.count(metDays: settings.metDays, today: today)
        let met = Set(settings.metDays)
        let monday = Self.mondayOfWeek(containing: today)
        let initials = lang == "th"
            ? ["จ.", "อ.", "พ.", "พฤ.", "ศ.", "ส.", "อา."]
            : ["M", "T", "W", "T", "F", "S", "S"]

        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(
                text: tr(lang, "Your streak", "ความต่อเนื่องของคุณ"),
                color: colors.inkAlpha(0.45)
            )
            Spacer().frame(height: 14)
            HStack(spacing: 0) {
                StreakRing(streak: streak)
                Spacer().frame(width: 20)
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        if i > 0 { Spacer(minLength: 0) }
                        let day = Calendar.current.date(byAdding: .day, value: i, to: monday) ?? monday
                        let key = AffirmationRepository.dayKey(day)
                        DayDot(
                            initial: initials[i],
                            met: met.contains(key),
                            isToday: key == todayKey,
                            isFuture: key > todayKey
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Spacer().frame(height: 12)
            Text(
                streak == 0
                    ? tr(lang, "Hold today's line to begin", "แตะค้างที่ประโยควันนี้ เพื่อเริ่มนับ")
                    : tr(lang, "Meet the line each morning — that's all it is", "พบกันทุกเช้า ก็เท่านั้นเอง")
            )
            .font(AttaType.sans(11))
            .tracking(0.5)
            .foregroundStyle(colors.inkAlpha(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.canvasAlt)
        .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusCard))
    }

    /// Monday of the week containing `date`, computed explicitly — never
    /// trusting the locale's firstWeekday. weekday is 1=Sun...7=Sat, so
    /// (weekday + 5) % 7 is days since Monday (Mon 0 ... Sun 6).
    static func mondayOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) ?? start
    }
}

/// The run count inside a thin champagne ring, one spark at its shoulder.
private struct StreakRing: View {
    @Environment(\.atta) private var colors
    let streak: Int

    var body: some View {
        ZStack {
            Canvas { context, size in
                let strokeWidth: CGFloat = 1.5
                let stroke = StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                let radius = min(size.width, size.height) / 2 - strokeWidth
                let ring = Path(ellipseIn: CGRect(
                    x: size.width / 2 - radius,
                    y: size.height / 2 - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.stroke(ring, with: .color(AttaPalette.champagne), style: stroke)
                // One spark, low right — the ring's quiet ornament.
                let c = CGPoint(x: size.width * 0.92, y: size.height * 0.84)
                let r = size.width * 0.055
                var spark = Path()
                spark.move(to: CGPoint(x: c.x - r, y: c.y))
                spark.addLine(to: CGPoint(x: c.x + r, y: c.y))
                spark.move(to: CGPoint(x: c.x, y: c.y - r))
                spark.addLine(to: CGPoint(x: c.x, y: c.y + r))
                context.stroke(spark, with: .color(AttaPalette.champagne), style: stroke)
            }
            .frame(width: 58, height: 58)
            Text("\(streak)")
                .font(AttaType.serif(24))
                .foregroundStyle(colors.ink)
        }
    }
}

private struct DayDot: View {
    @Environment(\.atta) private var colors
    let initial: String
    let met: Bool
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        VStack(spacing: 7) {
            Text(initial)
                .font(AttaType.sans(10))
                .foregroundStyle(colors.inkAlpha(isToday ? 0.7 : 0.4))
            ZStack {
                Circle()
                    .fill(
                        met
                            ? AttaPalette.champagne
                            : colors.inkAlpha(isFuture ? 0.05 : 0.12)
                    )
                    .frame(width: 22, height: 22)
                if met {
                    CheckMark()
                        .stroke(colors.canvas, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 10, height: 10)
                } else if isToday {
                    Circle()
                        .stroke(AttaPalette.champagne, lineWidth: 1)
                        .frame(width: 18, height: 18)
                }
            }
        }
    }
}

private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.85))
        p.addLine(to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.15))
        return p
    }
}
