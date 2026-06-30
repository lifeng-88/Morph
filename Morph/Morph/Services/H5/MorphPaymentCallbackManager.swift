//
//  MorphPaymentCallbackManager.swift
//  App
//

import Foundation

extension Notification.Name {
    static let morphPaymentCallbackReceived = Notification.Name("morphPaymentCallbackReceived")
}

final class MorphPaymentCallbackManager {
    static let shared = MorphPaymentCallbackManager()

    private init() {}

    func handle(url: URL) {
        let payload = payload(from: url)
        debugLog("callback url=\(url.absoluteString)")
        NotificationCenter.default.post(
            name: .morphPaymentCallbackReceived,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    private func payload(from url: URL) -> [String: Any] {
        var result: [String: Any] = [
            "url": url.absoluteString,
            "scheme": url.scheme ?? "",
            "host": url.host ?? "",
            "path": url.path
        ]

        for (key, value) in queryItems(from: url) {
            result[key] = value
        }

        if result["order_id"] == nil, let orderId = result["orderId"] {
            result["order_id"] = orderId
        }
        if result["transaction_id"] == nil, let transactionId = result["transactionId"] {
            result["transaction_id"] = transactionId
        }

        return result
    }

    private func queryItems(from url: URL) -> [String: String] {
        var items: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                items[item.name] = item.value ?? ""
            }
        }

        if let fragment = url.fragment,
           let fragmentComponents = URLComponents(string: fragment.hasPrefix("?") ? fragment : "?\(fragment)") {
            for item in fragmentComponents.queryItems ?? [] {
                items[item.name] = item.value ?? ""
            }
        }

        return items
    }

    private func debugLog(_ message: String) {
        guard MorphH5Config.debugLogging else { return }
        print("💳 [PaymentCallback] \(message)")
    }
}
