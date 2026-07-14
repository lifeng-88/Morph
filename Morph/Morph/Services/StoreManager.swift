import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var missingProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var didFinishLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var lastError: String?
    @Published private(set) var pendingCoinGrant: Int?

    private var transactionListener: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    private init() {
        transactionListener = Task { await listenForTransactions() }
    }

    deinit {
        transactionListener?.cancel()
        loadTask?.cancel()
    }

    func preloadProductsIfNeeded() {
        guard loadTask == nil, products.isEmpty, !isLoading else { return }
        loadTask = Task {
            await loadProducts(force: true)
            loadTask = nil
        }
    }

    func loadProducts(force: Bool = false) async {
        if isLoading { return }
        if !force, !products.isEmpty {
            didFinishLoading = true
            refreshMissingProductIDs()
            return
        }

        isLoading = true
        defer {
            isLoading = false
            didFinishLoading = true
        }

        let ids = Array(MorphCoinCatalog.productIDs)
        var merged = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        var lastFetchError: String?

        for attempt in 0..<3 {
            do {
                let fetched = try await Product.products(for: ids)
                for product in fetched {
                    merged[product.id] = product
                }
                if !merged.isEmpty {
                    products = merged.values.sorted { $0.price < $1.price }
                    refreshMissingProductIDs()
                    lastError = missingProductIDs.isEmpty ? nil : L10n.coinStorePartialProducts
                    return
                }
                lastFetchError = L10n.coinStoreProductUnavailable
            } catch {
                lastFetchError = MorphIAPSupport.userFacingMessage(for: error)
            }

            if attempt < 2 {
                try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 500_000_000))
            }
        }

        products = Array(merged.values).sorted { $0.price < $1.price }
        refreshMissingProductIDs()
        if products.isEmpty {
            lastError = lastFetchError
        }
    }

    func isProductAvailable(_ productID: String) -> Bool {
        product(for: productID) != nil
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func usesFallbackPrice(for pack: CoinPack) -> Bool {
        product(for: pack.productID) == nil
    }

    func displayPrice(for pack: CoinPack) -> String {
        product(for: pack.productID)?.displayPrice ?? pack.fallbackPrice
    }

    func restorePurchases() async -> RestoreResult {
        lastError = nil
        var recoveredCoins = 0

        do {
            try await AppStore.sync()
        } catch {
            let message = MorphIAPSupport.userFacingMessage(for: error)
            lastError = message
            return .failed(message: message)
        }

        for await result in Transaction.unfinished {
            recoveredCoins += await processTransactionResult(result, source: .restore)
        }

        if recoveredCoins > 0 {
            pendingCoinGrant = (pendingCoinGrant ?? 0) + recoveredCoins
            return .recovered(coins: recoveredCoins)
        }

        return .synced
    }

    func clearError() {
        lastError = nil
    }

    func consumePendingCoinGrant() {
        pendingCoinGrant = nil
    }

    func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            _ = await processTransactionResult(result, source: .startup)
        }
    }

    func purchase(productID: String) async -> PurchaseResult {
        lastError = nil
        purchasingProductID = productID
        defer { purchasingProductID = nil }

        guard let product = await resolveProduct(id: productID) else {
            let message = L10n.coinStoreProductUnavailable
            lastError = message
            return .failed(message: message)
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                return await handlePurchaseVerification(verification)
            case .userCancelled:
                return .cancelled
            case .pending:
                lastError = L10n.coinStorePurchasePending
                return .pending
            @unknown default:
                let message = L10n.coinStoreProductUnavailable
                lastError = message
                return .failed(message: message)
            }
        } catch {
            let message = MorphIAPSupport.userFacingMessage(for: error)
            lastError = message
            return .failed(message: message)
        }
    }

    private enum TransactionSource {
        case purchase
        case startup
        case restore
        case listener
    }

    private func handlePurchaseVerification(
        _ verification: VerificationResult<Transaction>
    ) async -> PurchaseResult {
        let transaction: Transaction
        do {
            transaction = try checkVerified(verification)
        } catch {
            let message = L10n.coinStoreVerificationFailed
            lastError = message
            return .failed(message: message)
        }

        let coins = await processTransactionResult(.verified(transaction), source: .purchase)
        if coins > 0 {
            return .success(coins: coins)
        }
        if MorphIAPSupport.hasGranted(transaction.id) {
            return .cancelled
        }
        let message = L10n.coinStoreProductUnavailable
        lastError = message
        return .failed(message: message)
    }

    @discardableResult
    private func processTransactionResult(
        _ result: VerificationResult<Transaction>,
        source: TransactionSource
    ) async -> Int {
        guard case .verified(let transaction) = result else { return 0 }
        guard !MorphIAPSupport.isH5Managed(transaction) else { return 0 }

        if let coins = MorphIAPSupport.fulfillNativeTransaction(transaction) {
            if source == .listener || source == .startup || source == .restore {
                pendingCoinGrant = (pendingCoinGrant ?? 0) + coins
            }
            await transaction.finish()
            return coins
        }

        if MorphIAPSupport.hasGranted(transaction.id) {
            await transaction.finish()
        }

        return 0
    }

    private func resolveProduct(id: String) async -> Product? {
        if let cached = product(for: id) {
            return cached
        }

        do {
            let fetched = try await Product.products(for: [id])
            guard let resolved = fetched.first else { return nil }
            if !products.contains(where: { $0.id == resolved.id }) {
                products.append(resolved)
                products.sort { $0.price < $1.price }
            }
            refreshMissingProductIDs()
            lastError = nil
            return resolved
        } catch {
            lastError = MorphIAPSupport.userFacingMessage(for: error)
            return nil
        }
    }

    private func refreshMissingProductIDs() {
        missingProductIDs = MorphCoinCatalog.productIDs.subtracting(Set(products.map(\.id)))
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            _ = await processTransactionResult(result, source: .listener)
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
