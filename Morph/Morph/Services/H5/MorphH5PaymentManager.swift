//
//  MorphH5PaymentManager.swift
//  App
//

import Foundation
import StoreKit

extension Notification.Name {
    static let morphPaymentTransactionUpdated = Notification.Name("morphPaymentTransactionUpdated")
}

@MainActor
final class MorphH5PaymentManager {
    static let shared = MorphH5PaymentManager()

    private let defaults = UserDefaults.standard
    private let orderMappingPrefix = "app.iap.order."
    private let payChannelMappingPrefix = "app.iap.payChannel."
    private var pendingTransactions: [UInt64: Transaction] = [:]
    private var updatesTask: Task<Void, Never>?
    private var isPurchasing = false

    private init() {}

    func startListening() {
        guard updatesTask == nil else { return }

        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.capture(result)
            }
        }
    }

    func purchase(params: [String: Any]) async -> [String: Any] {
        guard !isPurchasing else {
            return [
                "opened": false,
                "status": "failed",
                "code": "PURCHASE_IN_PROGRESS",
                "message": "Another purchase is already in progress."
            ]
        }

        let productId = (params["productId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !productId.isEmpty else {
            return [
                "opened": false,
                "status": "failed",
                "code": "NO_PRODUCT_ID",
                "message": "Apple product id is missing."
            ]
        }

        do {
            var lastError: String?
            var product: Product?

            for attempt in 0..<3 {
                let fetched = try await Product.products(for: [productId])
                if let resolved = fetched.first {
                    product = resolved
                    break
                }
                lastError = "Apple product is unavailable."
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 500_000_000))
                }
            }

            guard let product else {
                return [
                    "opened": false,
                    "status": "failed",
                    "code": "PRODUCT_NOT_FOUND",
                    "message": lastError ?? "Apple product is unavailable."
                ]
            }

            guard product.type == .consumable else {
                return [
                    "opened": false,
                    "status": "failed",
                    "code": "INVALID_PRODUCT_TYPE",
                    "message": "Apple product must be consumable."
                ]
            }

            isPurchasing = true
            defer { isPurchasing = false }

            let appAccountToken = UUID()
            let tokenKey = appAccountToken.uuidString
            if let orderId = params["orderId"] as? String, !orderId.isEmpty {
                defaults.set(orderId, forKey: orderMappingPrefix + appAccountToken.uuidString)
            }
            if let payChannelId = params["payChannelId"] {
                defaults.set(String(describing: payChannelId), forKey: payChannelMappingPrefix + tokenKey)
            }

            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    pendingTransactions[transaction.id] = transaction
                    return transactionPayload(
                        transaction,
                        status: "success",
                        opened: true,
                        appAccountToken: appAccountToken.uuidString,
                        orderId: params["orderId"] as? String
                    )
                case .unverified(_, let error):
                    return [
                        "opened": false,
                        "status": "failed",
                        "code": "UNVERIFIED_TRANSACTION",
                        "message": error.localizedDescription
                    ]
                }
            case .userCancelled:
                return [
                    "opened": true,
                    "status": "cancelled",
                    "message": "Purchase was cancelled."
                ]
            case .pending:
                return [
                    "opened": true,
                    "status": "processing",
                    "message": "Purchase is pending approval."
                ]
            @unknown default:
                return [
                    "opened": false,
                    "status": "failed",
                    "code": "UNKNOWN_PURCHASE_RESULT",
                    "message": "Unknown Apple purchase result."
                ]
            }
        } catch {
            return [
                "opened": false,
                "status": "failed",
                "code": "PURCHASE_FAILED",
                "message": error.localizedDescription
            ]
        }
    }

    func restoreTransactions() async -> [String: Any] {
        var restored: [[String: Any]] = []

        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result, MorphIAPSupport.isH5Managed(transaction) {
                pendingTransactions[transaction.id] = transaction
                restored.append(transactionPayload(transaction, status: "restored", opened: true))
            }
        }

        return [
            "restored": !restored.isEmpty,
            "transactions": restored
        ]
    }

    func finishTransaction(transactionId: String) async -> [String: Any] {
        guard let id = UInt64(transactionId),
              let transaction = pendingTransactions[id]
        else {
            return [
                "finished": false,
                "reason": "Transaction is not pending in native runtime."
            ]
        }

        await transaction.finish()
        pendingTransactions.removeValue(forKey: id)

        if let token = transaction.appAccountToken?.uuidString {
            defaults.removeObject(forKey: orderMappingPrefix + token)
            defaults.removeObject(forKey: payChannelMappingPrefix + token)
        }

        return ["finished": true]
    }

    private func capture(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard MorphIAPSupport.isH5Managed(transaction) else { return }

        pendingTransactions[transaction.id] = transaction
        NotificationCenter.default.post(
            name: .morphPaymentTransactionUpdated,
            object: nil,
            userInfo: ["payload": transactionPayload(transaction, status: "success", opened: true)]
        )
    }

    private func transactionPayload(
        _ transaction: Transaction,
        status: String,
        opened: Bool,
        appAccountToken: String? = nil,
        orderId: String? = nil
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "opened": opened,
            "status": status,
            "transactionId": String(transaction.id),
            "productId": transaction.productID,
            "originalTransactionId": String(transaction.originalID),
            "purchaseDate": Int(transaction.purchaseDate.timeIntervalSince1970)
        ]

        if let token = appAccountToken ?? transaction.appAccountToken?.uuidString {
            payload["appAccountToken"] = token
            payload["orderId"] = orderId ?? defaults.string(forKey: orderMappingPrefix + token) ?? NSNull()
            if let payChannelId = defaults.string(forKey: payChannelMappingPrefix + token) {
                payload["payChannelId"] = payChannelId
            }
        } else if let orderId {
            payload["orderId"] = orderId
        }

        return payload
    }
}
