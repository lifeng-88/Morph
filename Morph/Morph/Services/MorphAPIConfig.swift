import Foundation

enum MorphAPIConfig {
    private static let apiInfoKeys = ["MORPH_API_BASE_URL", "APIBaseURL"]
    private static let resInfoKeys = ["MORPH_RES_BASE_URL", "ResBaseURL"]

    static var effectiveAPIBaseURL: String {
        normalizedBaseURL(from: apiInfoKeys, defaultValue: "https://api.glamvid.xin")
    }

    static var effectiveResBaseURL: String {
        normalizedBaseURL(from: resInfoKeys, defaultValue: "https://res.glamvid.xin")
    }

    static var baseURL: URL? {
        URL(string: effectiveAPIBaseURL)
    }

    static var apiKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "MORPH_API_KEY") as? String,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return raw
    }

    static var isConfigured: Bool {
        baseURL != nil && apiKey != nil
    }

    private static func normalizedBaseURL(from keys: [String], defaultValue: String) -> String {
        for key in keys {
            if let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) {
                    return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
                }
            }
        }
        return defaultValue
    }
}
