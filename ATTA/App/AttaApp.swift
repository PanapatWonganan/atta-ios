import SwiftUI

@main
struct AttaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Every pushable destination in the app — the Compose NavHost route table.
enum Route: Hashable {
    case questions
    case processing
    case result
    case firstLine
    case commit
    case compare
    case valueRecap
    case trialPromise
    case paywall(source: String)
    case widgetMoment
    case practice(source: String, index: Int)
    case gallery
    case focus
    case saved
    case settings
    case about
    case line(id: String)
}

final class Router: ObservableObject {
    @Published var path: [Route] = []

    func push(_ route: Route) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }

    /// Onboarding handoff: root swaps to Home once onboardingDone flips, so
    /// resetting to just the widget moment mirrors Android's popUpTo(0).
    func resetTo(_ route: Route) { path = [route] }
}

struct RootView: View {
    @StateObject private var store = AttaStore.shared
    @StateObject private var router = Router()
    @StateObject private var billing = AttaBilling()
    @Environment(\.colorScheme) private var systemScheme

    private var dark: Bool {
        switch store.settings.appearance {
        case "light": false
        case "dark": true
        default: systemScheme == .dark
        }
    }

    var body: some View {
        let colors = AttaColors.resolve(dark: dark)
        NavigationStack(path: $router.path) {
            Group {
                if store.settings.onboardingDone {
                    HomeScreen()
                } else {
                    WelcomeScreen()
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(route)
            }
        }
        .overlay(alignment: .top) {
            // The streak's applause, above every screen: appears only in
            // the moment today's line gets met, then leaves on its own.
            StreakToastHost()
                .padding(.top, 12)
        }
        .environment(\.atta, colors)
        .environmentObject(store)
        .environmentObject(router)
        .environmentObject(billing)
        .tint(colors.ink)
        .preferredColorScheme(store.settings.appearance == "system" ? nil : (dark ? .dark : .light))
        .task {
            store.recordUsageDay()
            await billing.connect()
            Reminders.reschedule(store.settings)
        }
        .onChange(of: billing.purchasedPlan) { _, plan in
            guard let plan else { return }
            store.setPlan(plan)
            // A taken trial starts the day-5 clock (the note the trial-promise
            // screen commits to). Re-purchasing restarts it.
            TrialNote.planTaken(plan, store: store)
        }
        .onChange(of: store.settings.plan) { _, plan in
            // iOS can't re-check the plan when the note fires (Android's
            // worker does): a lifetime upgrade or a drop to free must cancel
            // the pending day-5 note right now.
            if plan == Plans.lifetime || Plans.isFree(plan) {
                TrialNote.cancel()
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        Group {
            switch route {
            case .questions: QuestionsScreen()
            case .processing: ProcessingScreen()
            case .result: ResultScreen()
            case .firstLine: FirstLineScreen()
            case .commit: CommitScreen()
            case .compare: ComparisonScreen()
            case .valueRecap: ValueRecapScreen()
            case .trialPromise: TrialPromiseScreen()
            case .paywall(let source): PaywallScreen(source: source)
            case .widgetMoment: WidgetMomentScreen()
            case .practice(let source, let index):
                PracticeScreen(source: source, startIndex: index)
            case .gallery: WidgetGalleryScreen()
            case .focus: FocusScreen()
            case .saved: SavedScreen()
            case .settings: SettingsScreen()
            case .about: AboutScreen()
            case .line(let id): ViewerScreenHost(id: id)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Route wrapper: resolves the line id and pops if it's gone (parity with Android).
struct ViewerScreenHost: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var store: AttaStore
    let id: String

    var body: some View {
        if let line = Affirmations.byId(id) ??
            CustomLines.parse(store.settings.customLines).first(where: { $0.id == id }) {
            ViewerScreen(line: line)
        } else {
            Color.clear.onAppear { router.pop() }
        }
    }
}
