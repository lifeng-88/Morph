import Foundation

/// Tracks explicit user consent before photos may be sent to third-party AI services.
enum AIDataConsentManager {
    static let currentPolicyVersion = 1

    private static let grantedKey = "morph.ai_data_consent.granted"
    private static let versionKey = "morph.ai_data_consent.version"

    static let thirdPartyProviderName = "Glamvid AI"
    static let thirdPartyDomains = "api.glamvid.xin, res.glamvid.xin, and glamvid.xin"

    static var hasGranted: Bool {
        UserDefaults.standard.bool(forKey: grantedKey)
            && UserDefaults.standard.integer(forKey: versionKey) >= currentPolicyVersion
    }

    static func grant() {
        UserDefaults.standard.set(true, forKey: grantedKey)
        UserDefaults.standard.set(currentPolicyVersion, forKey: versionKey)
        NotificationCenter.default.post(name: .morphAIDataConsentGranted, object: nil)
    }

    static func revoke() {
        UserDefaults.standard.set(false, forKey: grantedKey)
        UserDefaults.standard.set(0, forKey: versionKey)
    }
}

extension Notification.Name {
    static let morphAIDataConsentRequired = Notification.Name("morph.ai.consent.required")
    static let morphAIDataConsentGranted = Notification.Name("morph.ai.consent.granted")
}
