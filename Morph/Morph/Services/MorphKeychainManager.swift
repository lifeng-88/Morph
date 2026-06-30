import Foundation
import Security

enum MorphKeychainKey {
    static let devId = "morph.dev_id"
}

actor MorphKeychainManager {
    static let shared = MorphKeychainManager()

    private let service: String

    private init() {
        service = Bundle.main.bundleIdentifier ?? "com.morph.app"
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)

        var query = baseQuery(for: key)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MorphKeychainError.saveFailed(status)
        }
    }

    func load(key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

enum MorphKeychainError: Error {
    case saveFailed(OSStatus)
}
