import Foundation

final class MorphAppConfig: @unchecked Sendable {
    static let shared = MorphAppConfig()

    private static let channelKey = "ChannelId"
    private static let isTestKey = "isTest"

    static var buildDefaultChannelId: String {
        "IOS10065"
    }

    private init() {}

    static var isTest: Int {
        if let value = Bundle.main.object(forInfoDictionaryKey: isTestKey) as? Int { return value }
        if let value = Bundle.main.object(forInfoDictionaryKey: isTestKey) as? NSNumber { return value.intValue }
        if let raw = Bundle.main.object(forInfoDictionaryKey: isTestKey) as? String,
           let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return value
        }
        return 0
    }

    static var usesDebugFixedDeviceId: Bool {
        #if DEBUG
        return isTest == 1
        #else
        return false
        #endif
    }

    func getChannel() async -> String {
        Self.resolvedChannel()
    }

    static func resolvedChannel() -> String {
        for key in ["AppChannel", channelKey, "MORPH_H5_CHANNEL"] {
            if let value = plistString(for: key) {
                return value
            }
        }
        if let url = BSideConfig.localURL, let channel = BSideConfig.channel(from: url) {
            return channel
        }
        return buildDefaultChannelId
    }

    static func plistString(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }
}
