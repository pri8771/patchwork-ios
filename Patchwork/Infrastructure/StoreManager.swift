import Foundation
import StoreKit

/// StoreKit 2 monetization (locked decision #9): Free + Pro annual (default) + Lifetime.
/// No ads, no data sales, no server receipt validation — entitlement is checked entirely on
/// device against `Transaction.currentEntitlements`.
@MainActor
final class StoreManager: ObservableObject {
    static let annualID = "com.patchworkapp.pro.annual"
    static let lifetimeID = "com.patchworkapp.lifetime"
    static let productIDs = [annualID, lifetimeID]

    enum Tier: Equatable {
        case free
        case proAnnual
        case lifetime

        var isPro: Bool { self != .free }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var tier: Tier = .free
    @Published private(set) var isLoadingProducts = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var annualProduct: Product? { products.first { $0.id == Self.annualID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }
    var isPro: Bool { tier.isPro }

    init() {
        // Listen for transactions that arrive outside an explicit purchase (renewals, restores,
        // Ask-to-Buy approvals, purchases made on another device).
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verification: update)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            // Show Lifetime last; subscription first.
            products = loaded.sorted { $0.id < $1.id }
        } catch {
            lastError = "Couldn’t load the store. Check your connection and try again."
        }
        await refreshEntitlements()
    }

    /// Recomputes the current tier from on-device entitlements.
    func refreshEntitlements() async {
        var newTier: Tier = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate != nil { continue }
            if let exp = transaction.expirationDate, exp < .now { continue }
            switch transaction.productID {
            case Self.lifetimeID:
                newTier = .lifetime // strongest entitlement wins
            case Self.annualID:
                if newTier != .lifetime { newTier = .proAnnual }
            default:
                break
            }
        }
        tier = newTier
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification: verification)
                return isPro
            case .userCancelled:
                return false
            case .pending:
                lastError = "Your purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed. You weren’t charged."
            return false
        }
    }

    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
        } catch {
            lastError = "Couldn’t restore purchases. Try again."
        }
        await refreshEntitlements()
    }

    private func handle(verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}
