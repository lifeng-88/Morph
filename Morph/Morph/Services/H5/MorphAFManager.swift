//
//  MorphAFManager.swift
//  App
//

import Foundation
import UIKit

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

private let nativeAFHasObtainedAttributionKey = "af_has_obtained_attribution"
private let nativeAFHasCompletedLoginKey = "af_has_completed_login"
private let nativeAFAttributionJSONKey = "af_attribution_json"
private let nativeAFAfIDKey = "af_af_id"
private let nativeAFAdIDKey = "af_ad_id"
private let nativeAFSourceKey = "af_source"
private let nativeAFAttributionTimeoutSeconds: TimeInterval = 10

struct AFAttributionResult {
    var afId: String?
    var adId: String?
    var source: String?
    var attributionJson: String?

    static func timeoutFallback() -> AFAttributionResult {
        let timeoutJson = (try? JSONSerialization.data(withJSONObject: ["timeout": true]))
            .flatMap { String(data: $0, encoding: .utf8) }
        return AFAttributionResult(afId: nil, adId: nil, source: nil, attributionJson: timeoutJson)
    }

    var loginParameters: [String: Any] {
        var params: [String: Any] = [:]
        if let source = source?.trimmedNonEmpty { params["source"] = source }
        if let afId = afId?.trimmedNonEmpty { params["afId"] = afId }
        if let adId = adId?.trimmedNonEmpty { params["adId"] = adId }
        if let attributionJson = attributionJson?.trimmedNonEmpty {
            params["afAttributionJson"] = attributionJson
        }
        return params
    }
}

@MainActor
final class MorphAFManager {
    static let shared = MorphAFManager()

    private let defaults = UserDefaults.standard
    private var attributionResult: AFAttributionResult?
    private var attributionContinuation: CheckedContinuation<AFAttributionResult?, Never>?
    private var startedConfigurationKey: String?

    private init() {}

    func markLoginCompleted() {
        defaults.set(true, forKey: nativeAFHasCompletedLoginKey)
    }

    func getAttributionForLogin() async -> AFAttributionResult? {
        getAttributionForLoginCached()
    }

    func initAFAsync(channelId: String?) async {
        let effectiveChannel = effectiveChannel(channelId: channelId)
        _ = await configureAndStart(channelId: effectiveChannel)
    }

    func prepareForFirstLaunch(channelId: String?) async -> (canLogin: Bool, attribution: AFAttributionResult?) {
        let effectiveChannel = effectiveChannel(channelId: channelId)
        #if DEBUG
        if ProcessInfo.processInfo.environment["SIMULATE_AF_TIMEOUT"] == "1" {
            return (true, nil)
        }
        #endif
        guard await configureAndStart(channelId: effectiveChannel) else {
            return (true, nil)
        }
        let attribution = await waitForAttributionOrTimeout()
        return (true, attribution)
    }

    func prepareLoginAttribution(channelId: String?) async -> [String: Any] {
        let (_, rawAttribution) = await prepareForFirstLaunch(channelId: channelId)
        if let rawAttribution {
            return rawAttribution.loginParameters
        }

        return AFAttributionResult.timeoutFallback().loginParameters
    }

    func logEvent(
        channelId: String?,
        eventName: String,
        values: [String: Any]?
    ) async -> [String: Any] {
        let trimmedEventName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventName.isEmpty else {
            return [
                "logged": false,
                "code": "INVALID_EVENT_NAME",
                "message": "Event name is required."
            ]
        }

        let effectiveChannel = effectiveChannel(channelId: channelId)
        guard await configureAndStart(channelId: effectiveChannel) else {
            return [
                "logged": false,
                "code": "AF_NOT_CONFIGURED",
                "message": "AppsFlyer is not configured. Check remote AF config or Info.plist keys."
            ]
        }

        let afValues = Self.normalizedEventValues(values)
        return await withCheckedContinuation { continuation in
            MorphAFSDKBridge.logEvent(name: trimmedEventName, values: afValues.isEmpty ? nil : afValues) { result in
                Task { @MainActor in
                    switch result {
                    case let .success(response):
                        var payload: [String: Any] = [
                            "logged": true,
                            "eventName": trimmedEventName
                        ]
                        if !response.isEmpty {
                            payload["response"] = response
                        }
                        continuation.resume(returning: payload)
                    case let .failure(error):
                        continuation.resume(returning: [
                            "logged": false,
                            "code": "AF_LOG_EVENT_FAILED",
                            "message": error.localizedDescription,
                            "eventName": trimmedEventName
                        ])
                    }
                }
            }
        }
    }

    private static func normalizedEventValues(_ values: [String: Any]?) -> [String: Any] {
        guard let values else { return [:] }
        var result: [String: Any] = [:]
        for (key, value) in values {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty, let normalized = normalizedEventValue(value) else { continue }
            result[trimmedKey] = normalized
        }
        return result
    }

    private static func normalizedEventValue(_ value: Any) -> Any? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let int8 as Int8:
            return int8
        case let int16 as Int16:
            return int16
        case let int32 as Int32:
            return int32
        case let int64 as Int64:
            return int64
        case let uint as UInt:
            return uint
        case let float as Float:
            return float
        case let double as Double:
            return double
        case let dict as [String: Any]:
            let nested = normalizedEventValues(dict)
            return nested.isEmpty ? nil : nested
        case let array as [Any]:
            let normalized = array.compactMap { normalizedEventValue($0) }
            return normalized.isEmpty ? nil : normalized
        default:
            return nil
        }
    }

    func setAttribution(afId: String?, adId: String?, source: String?, attributionJson: String?) {
        let result = AFAttributionResult(
            afId: afId,
            adId: adId,
            source: source,
            attributionJson: attributionJson
        )
        attributionResult = result
        if let afId = afId?.trimmedNonEmpty { defaults.set(afId, forKey: nativeAFAfIDKey) }
        if let adId = adId?.trimmedNonEmpty { defaults.set(adId, forKey: nativeAFAdIDKey) }
        if let source = source?.trimmedNonEmpty { defaults.set(source, forKey: nativeAFSourceKey) }
        if let attributionJson = attributionJson?.trimmedNonEmpty {
            defaults.set(attributionJson, forKey: nativeAFAttributionJSONKey)
        }
        defaults.set(true, forKey: nativeAFHasObtainedAttributionKey)
        if let continuation = attributionContinuation {
            attributionContinuation = nil
            continuation.resume(returning: result)
        }
    }

    private func waitForAttributionOrTimeout() async -> AFAttributionResult? {
        if defaults.bool(forKey: nativeAFHasObtainedAttributionKey) {
            return getAttributionForLoginCached()
        }

        return await withCheckedContinuation { continuation in
            attributionContinuation = continuation
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(nativeAFAttributionTimeoutSeconds * 1_000_000_000))
                MorphAFManager.shared.timeoutAttribution()
            }
        }
    }

    private func timeoutAttribution() {
        guard let continuation = attributionContinuation else { return }
        attributionContinuation = nil
        defaults.set(true, forKey: nativeAFHasObtainedAttributionKey)
        continuation.resume(returning: getAttributionForLoginCached())
    }

    private func getAttributionForLoginCached() -> AFAttributionResult? {
        if let attributionResult { return attributionResult }
        let afId = defaults.string(forKey: nativeAFAfIDKey)
        let adId = defaults.string(forKey: nativeAFAdIDKey)
        let source = defaults.string(forKey: nativeAFSourceKey)
        let json = defaults.string(forKey: nativeAFAttributionJSONKey)
        if afId?.trimmedNonEmpty != nil || adId?.trimmedNonEmpty != nil || source?.trimmedNonEmpty != nil || json?.trimmedNonEmpty != nil {
            return AFAttributionResult(afId: afId, adId: adId, source: source, attributionJson: json)
        }
        return nil
    }

    private func configureAndStart(channelId: String) async -> Bool {
        let appleAppID = await MorphAFRemoteConfig.shared.getAppleAppID(channelId: channelId)
        let appsFlyerDevKey = await MorphAFRemoteConfig.shared.getAppsFlyerDevKey(channelId: channelId)

        guard let appleAppID, let appsFlyerDevKey else {
            print("[AF] Missing AF config for channel=\(channelId)")
            return false
        }

        let configurationKey = "\(appleAppID)|\(appsFlyerDevKey)"
        if startedConfigurationKey == configurationKey {
            return true
        }

        MorphAFSDKBridge.configure(appleAppID: appleAppID, appsFlyerDevKey: appsFlyerDevKey)
        MorphAFSDKBridge.start()
        startedConfigurationKey = configurationKey
        return true
    }

    private func effectiveChannel(channelId: String?) -> String {
        channelId?.trimmedNonEmpty
            ?? MorphH5Config.channel
            ?? MorphAppConfig.resolvedChannel()
    }
}

enum MorphAFSDKBridge {
    static func configure(appleAppID: String, appsFlyerDevKey: String) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().appleAppID = appleAppID
        AppsFlyerLib.shared().appsFlyerDevKey = appsFlyerDevKey
        AppsFlyerLib.shared().delegate = MorphAFDelegateWrapper.shared
        #else
        _ = appleAppID
        _ = appsFlyerDevKey
        #endif
    }

    static func start() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().start()
        #endif
    }

    static func handleOpen(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: options)
        #else
        _ = url
        _ = options
        #endif
    }

    static func continueUserActivity(_ userActivity: NSUserActivity) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        #else
        _ = userActivity
        #endif
    }

    static func logEvent(
        name: String,
        values: [String: Any]?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent(
            name: name,
            values: values,
            completionHandler: { response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                completion(.success(response ?? [:]))
            }
        )
        #else
        _ = name
        _ = values
        completion(.success([:]))
        #endif
    }
}

#if canImport(AppsFlyerLib)
private final class MorphAFDelegateWrapper: NSObject, AppsFlyerLibDelegate {
    static let shared = MorphAFDelegateWrapper()

    private override init() {
        super.init()
    }

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let afId = AppsFlyerLib.shared().getAppsFlyerUID()
        var payload = conversionInfo.reduce(into: [String: Any]()) { result, pair in
            if let key = pair.key as? String {
                result[key] = pair.value
            }
        }
        let trimmedAfId = afId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAfId.isEmpty {
            payload["appsflyer_id"] = trimmedAfId
        }
        let attributionJson = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) }
        let source = conversionInfo["media_source"] as? String
        Task { @MainActor in
            MorphAFManager.shared.setAttribution(
                afId: trimmedAfId.isEmpty ? nil : trimmedAfId,
                adId: nil,
                source: source,
                attributionJson: attributionJson
            )
        }
    }

    func onConversionDataFail(_ error: Error) {
        Task { @MainActor in
            MorphAFManager.shared.setAttribution(
                afId: nil,
                adId: nil,
                source: nil,
                attributionJson: nil
            )
        }
    }
}
#endif
