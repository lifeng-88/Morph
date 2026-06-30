import Foundation

private struct MorphAFConfigPayload: Decodable {
    var apple_app_id: String?
    var apps_flyer_dev_key: String?
    var appleAppId: String?
    var appsFlyerDevKey: String?

    var resolvedAppleAppId: String? { apple_app_id ?? appleAppId }
    var resolvedAppsFlyerDevKey: String? { apps_flyer_dev_key ?? appsFlyerDevKey }
}

actor MorphAFRemoteConfig {
    static let shared = MorphAFRemoteConfig()

    private let defaults = UserDefaults.standard

    private init() {}

    func getAppleAppID(channelId: String) async -> String? {
        let channel = normalizedChannel(channelId)
        if let cached = nonEmpty(defaults.string(forKey: keyAppleAppID(channel))) {
            return normalizeAppleAppID(cached)
        }
        if let (appleAppId, _) = await fetchAndCacheConfig(channelId: channel) {
            return appleAppId
        }
        for key in ["AppsFlyerAppleAppID", "MORPH_APPLE_APP_ID"] {
            if let fallback = MorphAppConfig.plistString(for: key) {
                return normalizeAppleAppID(fallback)
            }
        }
        return nil
    }

    func getAppsFlyerDevKey(channelId: String) async -> String? {
        let channel = normalizedChannel(channelId)
        if let cached = nonEmpty(defaults.string(forKey: keyAppsFlyerDevKey(channel))) {
            return cached
        }
        if let (_, devKey) = await fetchAndCacheConfig(channelId: channel) {
            return devKey
        }
        for key in ["AppsFlyerDevKey", "MORPH_APPSFLYER_DEV_KEY"] {
            if let fallback = MorphAppConfig.plistString(for: key) {
                return fallback
            }
        }
        return nil
    }

    private func fetchAndCacheConfig(channelId: String) async -> (appleAppId: String, appsFlyerDevKey: String)? {
        let base = MorphAPIConfig.effectiveResBaseURL
        let urlString = "\(base)/config/\(channelId).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let payload = try JSONDecoder().decode(MorphAFConfigPayload.self, from: data)
            guard let appleAppId = normalizeAppleAppID(nonEmpty(payload.resolvedAppleAppId)),
                  let devKey = nonEmpty(payload.resolvedAppsFlyerDevKey) else {
                return nil
            }
            defaults.set(appleAppId, forKey: keyAppleAppID(channelId))
            defaults.set(devKey, forKey: keyAppsFlyerDevKey(channelId))
            print("✅ [AFConfig] cached remote config channel=\(channelId)")
            return (appleAppId, devKey)
        } catch {
            print("⚠️ [AFConfig] fetch failed channel=\(channelId) error=\(error.localizedDescription)")
            return nil
        }
    }

    private func keyAppleAppID(_ channelId: String) -> String {
        "af_apple_app_id_\(channelId)"
    }

    private func keyAppsFlyerDevKey(_ channelId: String) -> String {
        "af_apps_flyer_dev_key_\(channelId)"
    }

    private func normalizedChannel(_ channelId: String) -> String {
        let trimmed = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? MorphAppConfig.buildDefaultChannelId : trimmed
    }

    private func normalizeAppleAppID(_ raw: String?) -> String? {
        guard var value = nonEmpty(raw) else { return nil }
        if value.lowercased().hasPrefix("id") {
            value = String(value.dropFirst(2))
        }
        return nonEmpty(value)
    }

    private func nonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }
}
