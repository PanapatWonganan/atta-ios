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

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    func connect() async {
        if Self.localTestingMode { return }
        do {
            let ids = [Self.weeklyProduct, Self.yearlyProduct, Self.lifetimeProduct]
            let loaded = try await Product.products(for: ids)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            ready = !products.isEmpty
            await refreshEntitlements()
            observeUpdates()
        } catch {
            ready = false
        }
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
