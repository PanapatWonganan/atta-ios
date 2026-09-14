import SwiftUI

/// The streak's small applause: when today's line gets met — held, practiced,
/// or checked in — a pill slides down from the top with the week's dots and
/// the count, holds a breath, and leaves on its own. It never appears on a
/// plain app open; the reward belongs to the act, not the arrival.
/// Port of Android StreakPill.kt.
struct StreakToastHost: View {
    @EnvironmentObject private var store: AttaStore
    @State private var lastMet: Bool?
    @State private var visible = false

    var body: some View {
        let metNow = Streak.metToday(metDays: store.settings.metDays)
        VStack {
            if visible {
                StreakPill(settings: store.settings)
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
            }
        }
        .animation(AttaMotion.ease(AttaMotion.screenEnter), value: visible)
        .onAppear {
            // Seeded with the current value: opening already-met stays silent.
            if lastMet == nil { lastMet = metNow }
        }
        .onChange(of: metNow) { _, now in
            guard now, lastMet == false else {
                lastMet = now
                return
            }
            lastMet = true
            visible = true
            Task {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                visible = false
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StreakPill: View {
    @Environment(\.atta) private var colors
    let settings: AttaSettings

    var body: some View {
        let streak = Streak.count(metDays: settings.metDays)
        let monday = Self.mondayOfWeek(containing: Date())
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let day = Calendar.current.date(byAdding: .day, value: i, to: monday) ?? monday
                Circle()
                    .fill(
                        settings.metDays.contains(AffirmationRepository.dayKey(day))
                            ? AttaPalette.champagne
                            : colors.inkAlpha(0.14)
                    )
                    .frame(width: 6, height: 6)
            }
            Spacer().frame(width: 6)
            Text(
                streak <= 1
                    ? tr(settings.language, "First morning met", "เช้าแรกของคุณ")
                    : tr(settings.language, "\(streak) mornings met", "\(streak) เช้าติดกัน")
            )
            .font(AttaType.sans(12.5, .medium))
            .tracking(0.3)
            .foregroundStyle(colors.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(colors.canvas)
        .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
        .overlay(
            RoundedRectangle(cornerRadius: AttaDimens.radiusButton)
                .stroke(colors.inkAlpha(0.14), lineWidth: 1)
        )
    }

    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start) // 1=Sun...7=Sat
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) ?? start
    }
}
