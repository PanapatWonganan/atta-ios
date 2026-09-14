import Foundation
import StoreKit

/// StoreKit 2 behind the app's local plan model. When the store isn't reachable
/// (simulators, dev builds) `ready` stays false and the paywall falls back to
/// setting the plan locally, so testing never blocks on a store.
@MainActor
final class AttaBilling: ObservableObject {

    /// TEMPORARY: local plans for testing. Set false for the App Store release.
    static let localTestingMode = true

    // Product ids to create in App Store Connect before release.
    static let weeklyProduct = "atta_weekly"
    static let yearlyProduct = "atta_yearly"
    static let lifetimeProduct = "atta_lifetime"

    @Published private(set) var ready = false
    @Published private(set) var purchasedPlan: String?

    /// The welcome-back deal: the yearly plan's priced introductory offer (or
    /// a promotional offer named welcome*), StoreKit 2's shape of Android's
    /// Play "welcome" offer. Nil until the store reports one; a free trial
    /// alone never becomes the deal.
    @Published private(set) var welcomeOffer: WelcomeOffer?

    struct WelcomeOffer: Equatable {
        let discounted: String // first-year price, formatted
        let original: String? // the plain recurring price it undercuts
        let perMonthApprox: String?
    }

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    func connect() async {
        if Self.localTestingMode { return }
        do {
            let ids = [Self.weeklyProduct, Self.yearlyProduct, Self.lifetimeProduct]
            let loaded = try await Product.products(for: ids)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            ready = !products.isEmpty
            if let yearly = products[Self.yearlyProduct] {
                welcomeOffer = Self.findWelcomeOffer(in: yearly)
            }
            await refreshEntitlements()
            observeUpdates()
        } catch {
            ready = false
        }
    }

    /// A priced intro on the yearly plan (pay-as-you-go or pay-up-front) or a
    /// promotional offer named welcome* becomes the returning-user deal. The
    /// free trial alone is not a discount, so it publishes nothing.
    private static func findWelcomeOffer(in yearly: Product) -> WelcomeOffer? {
        guard let sub = yearly.subscription else { return nil }
        let candidates = [sub.introductoryOffer].compactMap { $0 }
            + sub.promotionalOffers.filter { $0.id?.contains("welcome") == true }
        guard let offer = candidates.first(where: {
            $0.paymentMode == .payAsYouGo || $0.paymentMode == .payUpFront
        }) else { return nil }
        return WelcomeOffer(
            discounted: offer.displayPrice,
            original: yearly.displayPrice,
            perMonthApprox: (offer.price / 12).formatted(yearly.priceFormatStyle)
        )
    }

    /// Takes the welcome price. Platform difference vs Android: there is no
    /// offer token to pass — StoreKit applies the yearly plan's introductory
    /// offer automatically for users the store deems eligible.
    func purchaseWelcome() async {
        await purchase(planId: Plans.trialYearly)
    }

    func purchase(planId: String) async {
        guard let product = products[Self.productId(for: planId)] else { return }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result, case .verified(let tx) = verification {
            purchasedPlan = Self.plan(for: tx.productID)
            await tx.finish()
        }
    }

    /// "Restore purchase": re-reads what this Apple account already owns.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else { continue }
            if let plan = Self.plan(for: tx.productID) {
                purchasedPlan = plan
            }
        }
    }

    private func observeUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let tx) = update else { continue }
                await tx.finish()
                await MainActor.run {
                    self?.purchasedPlan = Self.plan(for: tx.productID)
                }
            }
        }
    }

    static func productId(for planId: String) -> String {
        switch planId {
        case Plans.trialWeekly: weeklyProduct
        case Plans.trialYearly: yearlyProduct
        default: lifetimeProduct
        }
    }

    static func plan(for productId: String) -> String? {
        switch productId {
        case weeklyProduct: Plans.trialWeekly
        case yearlyProduct: Plans.trialYearly
        case lifetimeProduct: Plans.lifetime
        default: nil
        }
    }
}
