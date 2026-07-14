import Foundation
import StoreKit

enum MorphIAPSupport {
    private static let grantedTransactionKey = "morph.iap.granted_transaction_ids"
    private static let orderMappingPrefix = "app.iap.order."
    private static let maxStoredIDs = 500

    static func isH5Managed(_ transaction: Transaction) -> Bool {
        transaction.appAccountToken != nil
    }

    static func hasGranted(_ transactionID: UInt64) -> Bool {
        storedIDs().contains(String(transactionID))
    }

    static func markGranted(_ transactionID: UInt64) {
        var ids = storedIDs()
        let value = String(transactionID)
        guard !ids.contains(value) else { return }
        ids.append(value)
        if ids.count > maxStoredIDs {
            ids = Array(ids.suffix(maxStoredIDs))
        }
        UserDefaults.standard.set(ids, forKey: grantedTransactionKey)
    }

    static func coinsForProduct(_ productID: String) -> Int? {
        MorphCoinCatalog.totalCoins(for: productID)
    }

    static func fulfillNativeTransaction(_ transaction: Transaction) -> Int? {
        guard !isH5Managed(transaction) else { return nil }
        guard transaction.productType == .consumable else { return nil }
        guard !hasGranted(transaction.id) else { return nil }
        guard let coins = coinsForProduct(transaction.productID), coins > 0 else { return nil }
        markGranted(transaction.id)
        return coins
    }

    static func userFacingMessage(for error: Error) -> String {
        if let storeError = error as? StoreError {
            switch storeError {
            case .failedVerification:
                return L10n.coinStoreVerificationFailed
            }
        }

        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return L10n.coinStoreProductUnavailable
            case .purchaseNotAllowed:
                return L10n.coinStorePurchaseNotAllowed
            case .ineligibleForOffer:
                return L10n.coinStoreProductUnavailable
            case .invalidQuantity:
                return L10n.coinStoreProductUnavailable
            @unknown default:
                return error.localizedDescription
            }
        }

        return error.localizedDescription
    }

    private static func storedIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: grantedTransactionKey) ?? []
    }
}

enum StoreError: Error {
    case failedVerification
}

enum PurchaseResult: Equatable {
    case success(coins: Int)
    case cancelled
    case pending
    case failed(message: String)
}

enum RestoreResult: Equatable {
    case synced
    case recovered(coins: Int)
    case failed(message: String)
}
