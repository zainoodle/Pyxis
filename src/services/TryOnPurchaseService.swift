import Foundation
import StoreKit
import Combine

@MainActor
final class TryOnPurchaseService: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var authorization: String?
    @Published private(set) var isPurchasing = false
    private var productID: String?
    private var observer: Task<Void, Never>?

    init() {
        #if DEBUG
        if let token = Bundle.main.object(forInfoDictionaryKey: "PYXIS_TRY_ON_TEST_TOKEN") as? String,
           token.count >= 32, !token.contains("$(") {
            authorization = "Test \(token)"
        }
        #endif
        observer = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = result, transaction.productID == self?.productID {
                    self?.accept(result)
                    await transaction.finish()
                }
            }
        }
    }
    deinit { observer?.cancel() }

    func refresh(productID: String?) async throws {
        self.productID = productID
        #if DEBUG
        if authorization?.hasPrefix("Test ") == true { return }
        #endif
        authorization = nil
        guard let productID, !productID.isEmpty else { product = nil; return }
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID { accept(result) }
        }
        product = try await Product.products(for: [productID]).first(where: {
            $0.type == .autoRenewable && $0.subscription?.subscriptionPeriod.unit == .month &&
            $0.subscription?.subscriptionPeriod.value == 1
        })
    }
    func purchase() async throws {
        guard let product else { throw TryOnError.unavailable }
        isPurchasing = true
        defer { isPurchasing = false }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result else { throw TryOnError.purchaseRequired }
            accept(result)
            await transaction.finish()
        case .pending: throw TryOnError.server("Your purchase is awaiting approval. Try-on will unlock when it is approved.")
        case .userCancelled: break
        @unknown default: break
        }
    }
    func restore() async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        try await AppStore.sync()
        try await refresh(productID: productID)
        if authorization == nil { throw TryOnError.server("No active try-on subscription was found for this Apple Account.") }
    }
    private func accept(_ result: VerificationResult<Transaction>) {
        guard case .verified(let transaction) = result,
              transaction.productID == productID,
              transaction.revocationDate == nil, !transaction.isUpgraded,
              let expires = transaction.expirationDate, expires > Date() else {
            authorization = nil; return
        }
        authorization = "Transaction \(result.jwsRepresentation)"
    }
}
