import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = Task { await listenForTransactions() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Array(MorphCoinCatalog.productIDs))
                .sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
            products = []
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(for pack: CoinPack) -> String {
        product(for: pack.productID)?.displayPrice ?? pack.fallbackPrice
    }

    func restorePurchases() async {
        lastError = nil
        try? await AppStore.sync()
    }

    @discardableResult
    func purchase(productID: String) async -> Int? {
        lastError = nil

        if let product = product(for: productID) {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    let coins = MorphCoinCatalog.totalCoins(for: productID) ?? 0
                    await transaction.finish()
                    return coins
                case .userCancelled, .pending:
                    return nil
                @unknown default:
                    return nil
                }
            } catch {
                lastError = error.localizedDescription
                return nil
            }
        }

        #if DEBUG
        return MorphCoinCatalog.totalCoins(for: productID)
        #else
        lastError = L10n.coinStoreProductUnavailable
        return nil
        #endif
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
