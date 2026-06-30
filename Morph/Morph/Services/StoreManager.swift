import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published private(set) var pendingCoinGrant: Int?

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
            if !products.isEmpty {
                lastError = nil
            }
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
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearError() {
        lastError = nil
    }

    func consumePendingCoinGrant() {
        pendingCoinGrant = nil
    }

    func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            await handleTransactionUpdate(result)
        }
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
                    defer { Task { await transaction.finish() } }
                    if let coins = fulfill(transaction) {
                        return coins
                    }
                    if IAPGrantStorage.hasGranted(transaction.id) {
                        return nil
                    }
                    lastError = L10n.coinStoreProductUnavailable
                    return nil
                case .userCancelled:
                    return nil
                case .pending:
                    lastError = L10n.coinStorePurchasePending
                    return nil
                @unknown default:
                    lastError = L10n.coinStoreProductUnavailable
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
            await handleTransactionUpdate(result)
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }

        if let coins = fulfill(transaction) {
            pendingCoinGrant = coins
        }

        await transaction.finish()
    }

    private func fulfill(_ transaction: Transaction) -> Int? {
        guard transaction.productType == .consumable else { return nil }
        guard !IAPGrantStorage.hasGranted(transaction.id) else { return nil }
        guard let coins = MorphCoinCatalog.totalCoins(for: transaction.productID), coins > 0 else {
            return nil
        }

        IAPGrantStorage.markGranted(transaction.id)
        return coins
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

private enum IAPGrantStorage {
    private static let key = "morph.iap.granted_transaction_ids"
    private static let maxStoredIDs = 500

    static func hasGranted(_ id: UInt64) -> Bool {
        storedIDs().contains(String(id))
    }

    static func markGranted(_ id: UInt64) {
        var ids = storedIDs()
        let value = String(id)
        guard !ids.contains(value) else { return }
        ids.append(value)
        if ids.count > maxStoredIDs {
            ids = Array(ids.suffix(maxStoredIDs))
        }
        UserDefaults.standard.set(ids, forKey: key)
    }

    private static func storedIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}

enum StoreError: Error {
    case failedVerification
}
