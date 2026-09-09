import SwiftUI

private struct PlanOption {
    let id: String
    let title: String
    let subtitle: String
    var mostChosen = false
}

private let planOptions: [PlanOption] = [
    PlanOption(id: Plans.trialWeekly, title: "Weekly", subtitle: "7 days free, then $2.99 / week"),
    PlanOption(id: Plans.trialYearly, title: "Yearly", subtitle: "7 days free, then $39.99 / year · $3.33 a month", mostChosen: true),
    PlanOption(id: Plans.lifetime, title: "Lifetime", subtitle: "$79.99 once. Yours for good"),
]

/// Closes without pressure: "Not now" is visible from second one, the trial
/// timeline makes the Day-5 reminder a stated feature, yearly is pre-selected
/// and framed per-month. No strikethroughs, no countdowns, no shaking buttons.
struct PaywallScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var billing: AttaBilling
    @Environment(\.atta) var colors
    let source: String

    @State private var selected = Plans.trialYearly
    @State private var showDownsell = false
    @State private var downsellSpent = false
    @State private var downsellTook = false

    /// Second "Not now" onward earns the one quiet weekly downsell.
    private var offerDownsell: Bool {
        store.settings.paywallDismisses >= 1 && Plans.isFree(store.settings.plan)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: declined) {
                    Text("Not now")
                        .font(AttaType.sans(14))
                        .foregroundStyle(colors.inkAlpha(0.45))
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 10)
                    Text("Keep tomorrow's line coming.")
                        .font(AttaType.serif(24))
                        .lineSpacing(6)
                        .foregroundStyle(colors.ink)
                        .frame(maxWidth: 300, alignment: .leading)
                    Spacer().frame(height: 10)
                    Text("Every theme, every category, and the widget on your home screen.")
                        .font(AttaType.sans(14))
                        .lineSpacing(4.5)
                        .foregroundStyle(colors.inkAlpha(0.6))
                        .frame(maxWidth: 300, alignment: .leading)
                    Spacer().frame(height: 22)
                    TimelineRow(lead: "Today", rest: "everything unlocks")
                    Spacer().frame(height: 10)
                    TimelineRow(lead: "Day 5", rest: "we remind you the trial is ending")
                    Spacer().frame(height: 10)
                    TimelineRow(lead: "Day 7", rest: "trial ends. Nothing charges before this")
                    Spacer().frame(height: 22)
                    VStack(spacing: 10) {
                        ForEach(planOptions, id: \.id) { plan in
                            PlanCard(plan: plan, selected: selected == plan.id) {
                                selected = plan.id
                            }
                        }
                    }
                    Spacer().frame(height: AttaDimens.md)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PrimaryButton(
                text: selected == Plans.lifetime ? "Unlock lifetime" : "Start my 7 days free"
            ) {
                subscribe(selected)
            }
            // AdMob rewarded day pass lands with the iOS ads pass
            Spacer().frame(height: 10)
            Button {
                Task { await billing.restore() }
            } label: {
                Text("Cancel anytime in two taps · Restore purchase")
                    .font(AttaType.sans(10.5))
                    .tracking(0.5)
                    .foregroundStyle(colors.inkAlpha(0.45))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
        // The soft counter-offer: acting on the outcome in onDismiss lets a
        // swipe-down count as the quiet "No thanks" it is.
        .sheet(isPresented: $showDownsell, onDismiss: {
            if downsellTook {
                downsellTook = false
                subscribe(Plans.trialWeekly)
            } else {
                close(Plans.isFree(store.settings.plan) ? Plans.free : nil)
            }
        }) {
            DownsellSheet(
                onTake: {
                    downsellTook = true
                    showDownsell = false
                },
                onDecline: { showDownsell = false }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(colors.canvas)
        }
    }

    /// "Not now" gets one soft counter-offer, never a second.
    private func declined() {
        if offerDownsell && !downsellSpent {
            downsellSpent = true
            showDownsell = true
        } else {
            close(Plans.isFree(store.settings.plan) ? Plans.free : nil)
        }
    }

    private func subscribe(_ planId: String) {
        if billing.ready {
            Task { await billing.purchase(planId: planId) }
        } else {
            // No store on this device/build: keep the local dev path.
            close(planId)
        }
    }

    private func close(_ plan: String?) {
        if let plan, plan != Plans.free {
            // Local-dev purchases skip the billing collector: stamp the trial
            // start and schedule the day-5 note here (Android's onPlanTaken).
            TrialNote.planTaken(plan, store: store)
        }
        if plan == nil || plan == Plans.free { store.recordPaywallDismiss() }
        if let plan { store.setPlan(plan) }
        if source == "onboarding" {
            store.setOnboardingDone()
            router.resetTo(.widgetMoment)
        } else {
            router.pop()
        }
    }
}

/// The soft counter-offer: one plan, no pressure, shown once per visit.
/// Port of Android DownsellSheet.
private struct DownsellSheet: View {
    @Environment(\.atta) private var colors
    let onTake: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Just the week, then decide.")
                .font(AttaType.serif(22))
                .lineSpacing(6)
                .foregroundStyle(colors.ink)
            Spacer().frame(height: 10)
            Text("No yearly promise. 7 days free, then $2.99 a week — cancel in two taps whenever.")
                .font(AttaType.sans(14))
                .lineSpacing(4.5)
                .foregroundStyle(colors.inkAlpha(0.6))
            Spacer().frame(height: AttaDimens.md)
            PrimaryButton(text: "Try the week", action: onTake)
            Spacer().frame(height: 6)
            Button(action: onDecline) {
                Text("No thanks")
                    .font(AttaType.sans(14))
                    .foregroundStyle(colors.inkAlpha(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusChip))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct TimelineRow: View {
    @Environment(\.atta) private var colors
    let lead: String
    let rest: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(AttaPalette.champagne)
                .frame(width: 12, height: 1)
            Spacer().frame(width: 10)
            (
                Text(lead).font(AttaType.sans(13.5, .medium))
                + Text(" — \(rest)").font(AttaType.sans(13.5))
            )
            .lineSpacing(3.75)
            .foregroundStyle(colors.inkAlpha(0.75))
        }
    }
}

private struct PlanCard: View {
    @Environment(\.atta) private var colors
    let plan: PlanOption
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(AttaType.sans(14, .medium))
                        .foregroundStyle(colors.ink)
                    Text(plan.subtitle)
                        .font(AttaType.sans(11.5))
                        .tracking(0.5)
                        .foregroundStyle(colors.inkAlpha(0.5))
                }
                Spacer(minLength: 8)
                if selected {
                    ZStack {
                        Circle().fill(AttaPalette.champagne).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(colors.canvas)
                    }
                } else {
                    Circle()
                        .stroke(colors.inkAlpha(0.25), lineWidth: 1)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(selected ? colors.card : colors.canvas)
            .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
            .overlay {
                RoundedRectangle(cornerRadius: AttaDimens.radiusButton)
                    .stroke(
                        selected ? AttaPalette.champagne : colors.inkAlpha(0.14),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(TapScaleStyle())
        .overlay(alignment: .topLeading) {
            if plan.mostChosen {
                Text("MOST CHOSEN")
                    .font(AttaType.sans(8, .medium))
                    .tracking(1)
                    .foregroundStyle(colors.canvas)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AttaPalette.champagne)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(x: 14, y: -7)
            }
        }
        .padding(.top, plan.mostChosen ? 7 : 0)
    }
}
