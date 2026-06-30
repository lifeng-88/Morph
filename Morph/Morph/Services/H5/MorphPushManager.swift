//
//  MorphPushManager.swift
//  App
//

import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let morphPushPayloadReceived = Notification.Name("morphPushPayloadReceived")
    static let morphPushTokenUpdated = Notification.Name("morphPushTokenUpdated")
}

final class MorphPushManager {
    static let shared = MorphPushManager()

    private let defaults = UserDefaults.standard
    private let tokenKey = "appPushToken"
    private let errorKey = "appPushLastError"
    private let launchPayloadKey = "appPushLaunchPayload"
    private let registrationTimeout: TimeInterval = 8

    private var registrationCompletions: [([String: Any]) -> Void] = []
    private var registrationTimeoutWorkItem: DispatchWorkItem?
    private var isRegisteringForRemoteNotifications = false

    private init() {}

    func startAutomaticRegistration() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            Self.logAuthorizationStatus(settings.authorizationStatus)

            switch settings.authorizationStatus {
            case .authorized, .ephemeral:
                self.beginRemoteNotificationRegistration()
            case .provisional:
                // Provisional = quiet delivery (no banner/sound). Upgrade to full alert like other packages.
                self.requestFullNotificationAuthorization(center: center) { granted in
                    guard granted else { return }
                    self.beginRemoteNotificationRegistration()
                }
            case .notDetermined:
                self.requestFullNotificationAuthorization(center: center) { granted in
                    guard granted else { return }
                    self.beginRemoteNotificationRegistration()
                }
            case .denied:
                print("⚠️ [Push] Automatic registration skipped: notification permission is denied")
            @unknown default:
                break
            }
        }
    }

    func register(completion: @escaping ([String: Any]) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            Self.logAuthorizationStatus(settings.authorizationStatus)

            switch settings.authorizationStatus {
            case .authorized, .ephemeral:
                self.registerForRemoteNotifications(completion: completion)
            case .provisional, .notDetermined:
                self.requestFullNotificationAuthorization(center: center) { granted in
                    if granted {
                        self.registerForRemoteNotifications(completion: completion)
                    } else {
                        let reason = self.defaults.string(forKey: self.errorKey)
                            ?? "Notification permission was denied."
                        completion(self.registrationResult(registered: false, reason: reason))
                    }
                }
            case .denied:
                completion(self.registrationResult(registered: false, reason: "Notification permission was denied."))
            @unknown default:
                completion(self.registrationResult(registered: false, reason: "Notification authorization status is unknown."))
            }
        }
    }

    private func requestFullNotificationAuthorization(
        center: UNUserNotificationCenter,
        completion: @escaping (Bool) -> Void
    ) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                self.storeRegistrationError(error.localizedDescription)
            }
            center.getNotificationSettings { settings in
                Self.logAuthorizationStatus(settings.authorizationStatus)
                completion(granted && settings.authorizationStatus == .authorized)
            }
        }
    }

    private static func logAuthorizationStatus(_ status: UNAuthorizationStatus) {
        let label: String
        switch status {
        case .notDetermined: label = "notDetermined"
        case .denied: label = "denied"
        case .authorized: label = "authorized (banners enabled)"
        case .provisional: label = "provisional (quiet — no banner/sound)"
        case .ephemeral: label = "ephemeral"
        @unknown default: label = "unknown"
        }
        print("📬 [Push] authorizationStatus = \(label)")
    }

    /// 当前缓存的 APNs device token（64 位十六进制），控制台会打印便于复制到 Apple 推送测试。
    func currentDeviceToken() -> String? {
        let token = defaults.string(forKey: tokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return token?.isEmpty == false ? token : nil
    }

    /// 启动时若已有缓存 token，打印到 Xcode 控制台（便于 Apple 推送测试页复制）。
    static func logCurrentDeviceTokenIfAvailable() {
        guard let token = shared.currentDeviceToken() else { return }
        logDeviceToken(token, source: "cached")
    }

    static func logDeviceToken(_ token: String, source: String) {
        #if DEBUG
        let apsEnv = "development (Debug build — use DEVELOPMENT in Apple Push Console)"
        #else
        let apsEnv = "production (Release build — use PRODUCTION in Apple Push Console)"
        #endif
        print("""
📬 [Push] APNs Device Token [\(source)]
   \(apsEnv)
   length: \(token.count) hex chars
   token (copy for Apple console):
\(token)
""")
    }

    func updateDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async {
            self.defaults.set(token, forKey: self.tokenKey)
            self.defaults.removeObject(forKey: self.errorKey)
            self.isRegisteringForRemoteNotifications = false
            self.registrationTimeoutWorkItem?.cancel()
            self.registrationTimeoutWorkItem = nil
            self.finishPendingRegistrations(with: self.registrationResult(registered: true, reason: nil))
            Self.logDeviceToken(token, source: "APNs")
            NotificationCenter.default.post(
                name: .morphPushTokenUpdated,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }

    func updateRegistrationFailure(_ error: Error) {
        DispatchQueue.main.async {
            self.storeRegistrationError(error.localizedDescription)
            self.isRegisteringForRemoteNotifications = false
            self.registrationTimeoutWorkItem?.cancel()
            self.registrationTimeoutWorkItem = nil
            self.finishPendingRegistrations(with: self.registrationResult(
                registered: false,
                reason: error.localizedDescription
            ))
        }
    }

    /// Persists payload for cold start so H5 can query it when needed.
    func deliverPayload(_ userInfo: [AnyHashable: Any], source: String = "unknown") {
        Self.logAPNsPayloadShape(userInfo, source: source)
        var payload = Self.normalizedPayload(from: userInfo)
        if payload.isEmpty {
            payload = Self.fallbackPayload(from: userInfo)
        }

        guard !payload.isEmpty,
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload)
        else {
            print("⚠️ [Push] Ignored notification [\(source)] — payload not JSON-serializable. userInfo=\(userInfo)")
            return
        }

        defaults.set(data, forKey: launchPayloadKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .morphPushPayloadReceived,
                object: nil,
                userInfo: ["payload": payload, "source": source]
            )
            print("📬 [Push] Delivered [\(source)]: \(payload)")
        }
    }

    func captureLaunchPayload(_ userInfo: [AnyHashable: Any], source: String = "capture") {
        deliverPayload(userInfo, source: source)
    }

    func consumeLaunchPayload() -> [String: Any] {
        guard let data = defaults.data(forKey: launchPayloadKey),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        defaults.removeObject(forKey: launchPayloadKey)
        return ["payload": payload]
    }

    private func registerForRemoteNotifications(completion: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let token = self.defaults.string(forKey: self.tokenKey), !token.isEmpty {
                Self.logDeviceToken(token, source: "push.register (cached)")
                completion(self.registrationResult(registered: true, reason: nil))
                return
            }

            self.registrationCompletions.append(completion)
            self.scheduleRegistrationTimeout()
            self.beginRemoteNotificationRegistration()
        }
    }

    private func beginRemoteNotificationRegistration() {
        DispatchQueue.main.async {
            guard !self.isRegisteringForRemoteNotifications else { return }
            self.isRegisteringForRemoteNotifications = true
            if MorphH5Config.debugLogging {
                print("📬 [Push] registerForRemoteNotifications()")
            }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func registrationResult(registered: Bool, reason: String?) -> [String: Any] {
        let token = defaults.string(forKey: tokenKey)
        var result: [String: Any] = [
            "registered": registered,
            "token": token ?? NSNull(),
            "push_id": token ?? NSNull()
        ]

        if let reason {
            result["reason"] = reason
        } else if let lastError = defaults.string(forKey: errorKey), !registered {
            result["reason"] = lastError
        }

        return result
    }

    private func scheduleRegistrationTimeout() {
        registrationTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.registrationCompletions.isEmpty else { return }

            self.isRegisteringForRemoteNotifications = false
            self.finishPendingRegistrations(with: self.registrationResult(
                registered: false,
                reason: self.defaults.string(forKey: self.errorKey)
                    ?? "APNs token callback did not return within \(Int(self.registrationTimeout)) seconds. Check Push Notifications capability, aps-environment entitlement, APNs network access, and simulator/device support."
            ))
        }
        registrationTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + registrationTimeout, execute: workItem)
    }

    private func finishPendingRegistrations(with result: [String: Any]) {
        let completions = registrationCompletions
        registrationCompletions.removeAll()
        completions.forEach { $0(result) }
    }

    private func storeRegistrationError(_ message: String) {
        defaults.set(message, forKey: errorKey)
    }

    private static func logAPNsPayloadShape(_ userInfo: [AnyHashable: Any], source: String) {
        guard let aps = userInfo["aps"] as? [AnyHashable: Any] else {
            print("📬 [Push] [\(source)] aps missing — not a standard APNs payload")
            return
        }
        let hasAlert = aps["alert"] != nil
        let contentAvailable: Bool = {
            guard let flag = aps["content-available"] else { return false }
            if let number = flag as? NSNumber { return number.intValue == 1 }
            if let number = flag as? Int { return number == 1 }
            if let bool = flag as? Bool { return bool }
            return false
        }()
        let pushKind: String
        if hasAlert && contentAvailable {
            pushKind = "alert + content-available (should show banner if authorized)"
        } else if hasAlert {
            pushKind = "alert (normal visible notification)"
        } else if contentAvailable {
            pushKind = "silent (content-available only — no system banner)"
        } else {
            pushKind = "unknown/custom"
        }
        print("📬 [Push] [\(source)] APNs kind = \(pushKind), aps keys = \(aps.keys)")
    }

    private static func normalizedPayload(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var payload: [String: Any] = [:]

        for (key, value) in userInfo {
            guard let key = stringKey(from: key),
                  key != "aps",
                  let normalized = normalizedValue(value)
            else { continue }

            payload[key] = normalized
        }

        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            payload.merge(apsSummary(from: aps), uniquingKeysWith: { current, _ in current })
        }

        if let glam = payload["glam"] as? [String: Any] {
            for (key, value) in glam where payload[key] == nil {
                payload[key] = value
            }
        } else if let glam = userInfo.first(where: { stringKey(from: $0.key) == "glam" })?.value as? [AnyHashable: Any] {
            for (key, value) in glam {
                guard let key = stringKey(from: key),
                      payload[key] == nil,
                      let normalized = normalizedValue(value)
                else { continue }

                payload[key] = normalized
            }
        }

        return payload
    }

    /// Silent / data-only pushes may have no custom keys; still forward `aps` summary.
    private static func fallbackPayload(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var payload: [String: Any] = [:]

        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            payload.merge(apsSummary(from: aps), uniquingKeysWith: { current, _ in current })
            if let flag = aps["content-available"] {
                let enabled: Bool
                if let number = flag as? NSNumber {
                    enabled = number.intValue == 1
                } else if let number = flag as? Int {
                    enabled = number == 1
                } else if let bool = flag as? Bool {
                    enabled = bool
                } else {
                    enabled = false
                }
                if enabled {
                    payload["contentAvailable"] = true
                }
            }
        }

        for (key, value) in userInfo {
            guard let key = stringKey(from: key), key != "aps", payload[key] == nil else { continue }
            if let normalized = normalizedValue(value) {
                payload[key] = normalized
            } else {
                payload[key] = String(describing: value)
            }
        }

        return payload
    }

    /// Apple console test pushes often contain only `aps`; expose alert text so the page can still react.
    private static func apsSummary(from aps: [AnyHashable: Any]) -> [String: Any] {
        var summary: [String: Any] = [:]

        if let alert = aps["alert"] {
            if let text = alert as? String {
                summary["alert"] = text
                summary["title"] = text
            } else if let alertDict = alert as? [AnyHashable: Any] {
                if let title = alertDict["title"] as? String { summary["title"] = title }
                if let body = alertDict["body"] as? String {
                    summary["body"] = body
                    if summary["title"] == nil { summary["title"] = body }
                }
                if let subtitle = alertDict["subtitle"] as? String { summary["subtitle"] = subtitle }
            }
        }

        if let badge = aps["badge"] { summary["badge"] = badge }
        if let sound = aps["sound"] as? String { summary["sound"] = sound }
        return summary.compactMapValues { normalizedValue($0) }
    }

    private static func stringKey(from key: AnyHashable) -> String? {
        if let string = key as? String { return string }
        if let string = key as? NSString { return string as String }
        return nil
    }

    private static func normalizedValue(_ value: Any) -> Any? {
        switch value {
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number
        case let dict as [AnyHashable: Any]:
            var normalized: [String: Any] = [:]
            for (key, value) in dict {
                guard let key = stringKey(from: key),
                      let nested = normalizedValue(value)
                else { continue }
                normalized[key] = nested
            }
            return normalized
        case let array as [Any]:
            return array.compactMap { normalizedValue($0) }
        default:
            return nil
        }
    }
}
