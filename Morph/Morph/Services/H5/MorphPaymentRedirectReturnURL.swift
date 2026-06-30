//
//  MorphPaymentRedirectReturnURL.swift
//  App
//
//  Redirect payment return path passed as page_url. Payment gateways navigate
//  the in-app WKWebView here; native intercepts it, closes the page, then the
//  page checks order status.
//

import Foundation

enum MorphPaymentRedirectReturnURL {
    static let string = "/local/recharge/return"
    private static let path = "/local/recharge/return"

    static func matches(_ url: URL) -> Bool {
        if url.path.lowercased() == Self.path {
            return true
        }

        guard url.scheme?.lowercased() == "app" else { return false }
        guard url.host?.lowercased() == "recharge" else { return false }
        let returnPath = url.path.lowercased()
        return returnPath == "/return" || returnPath == "return"
    }
}
