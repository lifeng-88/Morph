//
//  MorphJSONCacheManager.swift
//  App
//

import Foundation
import CryptoKit

final class MorphJSONCacheManager {
    static let shared = MorphJSONCacheManager()

    private let fileManager = FileManager.default
    private let directory: URL
    private let defaultTTL: TimeInterval = 24 * 60 * 60
    private let maxFiles = 120

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("AppJSONCache", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func value(namespace: String, key: String) -> [String: Any] {
        let fileURL = fileURL(namespace: namespace, key: key)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            debugLog("miss \(namespace) key=\(key)")
            return ["cached": false]
        }

        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            try? fileManager.removeItem(at: fileURL)
            debugLog("corrupt removed \(namespace) key=\(key)")
            return ["cached": false]
        }

        let now = Date().timeIntervalSince1970
        let expiresAt = object["expiresAt"] as? TimeInterval ?? 0
        if expiresAt > 0 && now > expiresAt {
            try? fileManager.removeItem(at: fileURL)
            debugLog("expired \(namespace) key=\(key)")
            return ["cached": false]
        }

        debugLog("hit \(namespace) key=\(key)")
        return [
            "cached": true,
            "updatedAt": object["updatedAt"] ?? NSNull(),
            "value": object["value"] ?? NSNull()
        ]
    }

    func setValue(namespace: String, key: String, value: Any, ttlSeconds: TimeInterval?) -> Bool {
        guard !key.isEmpty else {
            return false
        }

        guard JSONSerialization.isValidJSONObject(["value": value]) else {
            return false
        }

        let now = Date().timeIntervalSince1970
        let ttl = ttlSeconds ?? defaultTTL
        let object: [String: Any] = [
            "updatedAt": now,
            "expiresAt": ttl > 0 ? now + ttl : 0,
            "value": value
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            try data.write(to: fileURL(namespace: namespace, key: key), options: .atomic)
            trimIfNeeded()
            debugLog("saved \(namespace) key=\(key)")
            return true
        } catch {
            print("⚠️ [JSONCache] save failed: \(error.localizedDescription)")
            return false
        }
    }

    private func fileURL(namespace: String, key: String) -> URL {
        let safeName = stableCacheFileName(namespace: namespace, key: key) + ".json"
        return directory.appendingPathComponent(safeName)
    }

    private func stableCacheFileName(namespace: String, key: String) -> String {
        let raw = "\(namespace)__\(key)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func debugLog(_ message: String) {
        guard MorphH5Config.debugLogging else { return }
        print("🧊 [JSONCache] \(message)")
    }

    private func trimIfNeeded() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ), files.count > maxFiles else {
            return
        }

        let sorted = files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }

        for file in sorted.prefix(files.count - maxFiles) {
            try? fileManager.removeItem(at: file)
        }
    }
}
