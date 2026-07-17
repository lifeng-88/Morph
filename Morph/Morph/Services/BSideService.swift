import Combine
import Foundation

enum BSideConfig {
    /// Local override URL from Info.plist. Used when app_config routes to B-side.
    static var localURL: URL? {
        url(fromInfoKey: "MORPH_B_SIDE_URL")
    }

    /// Legacy remote config endpoint returning `{ "enabled": true, "url": "https://..." }`.
    static var remoteConfigURL: URL? {
        url(fromInfoKey: "MORPH_B_SIDE_CONFIG_URL")
    }

    static var isConfigured: Bool {
        localURL != nil || remoteConfigURL != nil
    }

    static func channel(from url: URL) -> String? {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "channel" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else { return nil }
        return raw
    }

    static func urlAppendingDeviceId(_ url: URL, deviceId: String) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "did" }
        items.append(URLQueryItem(name: "did", value: deviceId))
        components.queryItems = items
        return components.url ?? url
    }

    private static func url(fromInfoKey key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: raw) else { return nil }
        return url
    }
}

struct BSideRemoteConfig: Decodable {
    let enabled: Bool
    let url: String?

    var resolvedURL: URL? {
        guard enabled, let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }
}

@MainActor
final class BSideManager: ObservableObject {
    static let shared = BSideManager()

    enum Phase: Equatable {
        case loading
        case native
        case web(URL)
    }

    @Published private(set) var phase: Phase = .loading

    var canSwitchToBSide: Bool {
        #if DEBUG
        return BSideConfig.isConfigured
        #else
        return false
        #endif
    }

    private var bootstrapInFlight: Task<Void, Never>?
    private var remoteRefreshInFlight: Task<Void, Never>?

    private init() {
        phase = Self.initialPhase()
        // 只记录 URL，不在启动时创建 WKWebView（避免 WebProcess 堆积）
        if case .web(let url) = phase {
            MorphH5Preloader.prepare(url: url)
        }
    }

    func bootstrapFromRemote() async {
        if MorphAppConfigPersistence.hasPersistedSuccessfulFetch {
            await applyPersistedPresentationType(MorphAppConfigPersistence.readPersistedPresentationType())
            Task(priority: .utility) { await self.refreshIfNeeded() }
            return
        }

        if let inFlight = bootstrapInFlight {
            await inFlight.value
            return
        }

        let task = Task { await self.performFirstLaunchBootstrap() }
        bootstrapInFlight = task
        await task.value
        bootstrapInFlight = nil
    }

    func refreshIfNeeded(minInterval: TimeInterval = 300, force: Bool = false) async {
        if !MorphAppConfigPersistence.hasPersistedSuccessfulFetch {
            await bootstrapFromRemote()
            return
        }

        if !force {
            let last = UserDefaults.standard.double(forKey: MorphAppConfigPersistence.lastRemoteRefreshKey)
            guard last <= 0 || Date().timeIntervalSince1970 - last >= minInterval else { return }
        }

        if let inFlight = remoteRefreshInFlight {
            await inFlight.value
            return
        }

        let task = Task { await self.fetchAppConfigFromNetwork() }
        remoteRefreshInFlight = task
        await task.value
        remoteRefreshInFlight = nil
    }

    func switchToBSide() async {
        guard AIDataConsentManager.hasGranted else { return }
        if let url = await resolveBSideURL() {
            presentBSide(at: url)
            MorphAppConfigPersistence.persistSuccessfulPresentationType(2)
        }
    }

    func switchToNative() {
        phase = .native
        MorphH5Preloader.clear()
        UserDefaults.standard.removeObject(forKey: MorphAppConfigPersistence.cachedBSideURLKey)
        MorphAppConfigPersistence.persistSuccessfulPresentationType(1)
    }

    private static func initialPhase() -> Phase {
        guard MorphAppConfigPersistence.hasPersistedSuccessfulFetch else {
            return .loading
        }
        let type = MorphAppConfigPersistence.readPersistedPresentationType()
        if type == 2,
           BSideConfig.isConfigured,
           AIDataConsentManager.hasGranted,
           let cachedURL = cachedBSideURL() {
            return .web(cachedURL)
        }
        // type=2 但尚无缓存 URL：先显示 native，后台 bootstrap 再切 B 面，避免卡死启动页
        return .native
    }

    private static func cachedBSideURL() -> URL? {
        guard let raw = UserDefaults.standard.string(forKey: MorphAppConfigPersistence.cachedBSideURLKey),
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    private func cacheBSideURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: MorphAppConfigPersistence.cachedBSideURLKey)
    }

    private func presentBSide(at url: URL) {
        cacheBSideURL(url)
        MorphH5Preloader.prepare(url: url)
        // 已在同一 B 面 URL 时不再重复发布，避免 SwiftUI 反复重建 WebView
        if case .web(let current) = phase, current == url {
            return
        }
        phase = .web(url)
    }

    private func performFirstLaunchBootstrap() async {
        phase = .loading
        print("📱 [BSideManager] app_config 首启：默认 A 面，等待 AF 后请求")

        let channel = await MorphAppConfig.shared.getChannel()
        let (_, rawAttribution) = await MorphAFManager.shared.prepareForFirstLaunch(channelId: channel)
        await applyAppConfigResponse(await requestAppConfig(channel: channel, attribution: rawAttribution))
    }

    private func fetchAppConfigFromNetwork() async {
        let channel = await MorphAppConfig.shared.getChannel()
        let rawAttribution = await MorphAFManager.shared.getAttributionForLogin()
        let result = await requestAppConfig(channel: channel, attribution: rawAttribution)
        if case .success = result {
            UserDefaults.standard.set(
                Date().timeIntervalSince1970,
                forKey: MorphAppConfigPersistence.lastRemoteRefreshKey
            )
        }
        await applyAppConfigResponse(result)
    }

    private func requestAppConfig(
        channel: String,
        attribution raw: AFAttributionResult?
    ) async -> Result<MorphAppConfigResponse, MorphAppConfigError> {
        let attribution = raw ?? AFAttributionResult.timeoutFallback()
        let deviceId = await MorphDeviceManager.shared.getDeviceId()
        let version = await MorphDeviceManager.shared.getAppVersion()
        let request = MorphAppConfigRequest(
            devId: deviceId,
            source: attribution.source,
            channel: channel,
            version: version,
            afId: attribution.afId,
            afAttributionJson: attribution.attributionJson
        )
        print("📱 [BSideManager] 请求 /v1/app_config channel=\(channel) version=\(version)")
        return await MorphAppConfigService.fetchAppConfig(request: request)
    }

    private func applyAppConfigResponse(_ result: Result<MorphAppConfigResponse, MorphAppConfigError>) async {
        switch result {
        case .success(let response):
            if let type = response.type, type == 1 || type == 2 {
                MorphAppConfigPersistence.persistSuccessfulPresentationType(type)
                await applyPresentationType(type)
                print("✅ [BSideManager] app_config 成功 type=\(type) → \(type == 2 ? "B面" : "A面")")
            } else if !MorphAppConfigPersistence.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: "invalid_type")
            }
        case .failure(let error):
            if !MorphAppConfigPersistence.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: error.localizedDescription)
            } else {
                print("⚠️ [BSideManager] app_config 刷新失败(\(error.localizedDescription))，保留本地 type=\(MorphAppConfigPersistence.readPersistedPresentationType())")
            }
        }
    }

    private func applyPresentationType(_ type: Int) async {
        if type == 2, AIDataConsentManager.hasGranted, let url = await resolveBSideURL() {
            presentBSide(at: url)
        } else {
            phase = .native
        }
    }

    private func applyPersistedPresentationType(_ type: Int) async {
        if type == 2, AIDataConsentManager.hasGranted {
            if let cached = Self.cachedBSideURL() {
                presentBSide(at: cached)
            } else if let url = await resolveBSideURL() {
                presentBSide(at: url)
            } else {
                phase = .native
            }
        } else {
            phase = .native
        }
        let effective = (type == 2 && AIDataConsentManager.hasGranted) ? "B面" : "A面"
        print("✅ [BSideManager] app_config 使用本地缓存 type=\(type) → \(effective)")
    }

    private func applyFirstLaunchFailure(reason: String) {
        phase = .native
        print("❌ [BSideManager] app_config 首启失败(\(reason))，进 A 面且不保存")
    }

    private func resolveBSideURL() async -> URL? {
        let deviceId = await MorphDeviceManager.shared.getDeviceId()
        let baseURL: URL?
        if let localURL = BSideConfig.localURL {
            baseURL = localURL
        } else if let configURL = BSideConfig.remoteConfigURL {
            baseURL = await fetchRemoteURL(from: configURL)
        } else {
            baseURL = nil
        }
        guard let baseURL else { return nil }
        let resolved = BSideConfig.urlAppendingDeviceId(baseURL, deviceId: deviceId)
        cacheBSideURL(resolved)
        return resolved
    }

    private func fetchRemoteURL(from configURL: URL) async -> URL? {
        var request = URLRequest(url: configURL)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            let config = try JSONDecoder().decode(BSideRemoteConfig.self, from: data)
            return config.resolvedURL
        } catch {
            return nil
        }
    }
}
