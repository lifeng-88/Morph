import Foundation
import WebKit

enum MorphH5Config {
    private(set) static var pageChannel: String?

    static let appDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Morph"

    static var buildConfigurationLabel: String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var channel: String? {
        pageChannel ?? MorphAppConfig.resolvedChannel()
    }

    static var appleAppID: String? {
        MorphAppConfig.plistString(for: "MORPH_APPLE_APP_ID")
            ?? MorphAppConfig.plistString(for: "AppsFlyerAppleAppID")
    }

    static var appsFlyerDevKey: String? {
        MorphAppConfig.plistString(for: "MORPH_APPSFLYER_DEV_KEY")
            ?? MorphAppConfig.plistString(for: "AppsFlyerDevKey")
    }

    static var privacyURL: URL? {
        guard let raw = plistValue(for: "MORPH_PRIVACY_URL") else { return nil }
        return URL(string: raw)
    }

    static var debugLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func configure(pageURL: URL) {
        pageChannel = BSideConfig.channel(from: pageURL)
    }

    static func configureWebViewInspectability(_ webView: WKWebView) {
        if #available(iOS 16.4, *) {
            #if DEBUG
            webView.isInspectable = true
            #endif
        }
    }

    private static func plistValue(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
