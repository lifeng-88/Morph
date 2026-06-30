import Foundation
import UIKit

actor MorphDeviceManager {
    static let shared = MorphDeviceManager()

    #if DEBUG
    private static let debugDefaultDeviceId = "C54E5F2F-64C6-4C7A-88CB-7A5F329F2D47"
    #endif

    private init() {}

    func getDeviceId() async -> String {
        #if DEBUG
        if MorphAppConfig.usesDebugFixedDeviceId {
            return Self.debugDefaultDeviceId
        }
        #endif
        return await resolvedKeychainDeviceId()
    }

    func getAppVersion() async -> String {
        await MainActor.run {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        }
    }

    private func resolvedKeychainDeviceId() async -> String {
        let keychain = MorphKeychainManager.shared
        if let saved = await keychain.load(key: MorphKeychainKey.devId),
           !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return saved
        }

        let newId = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }

        do {
            try await keychain.save(key: MorphKeychainKey.devId, value: newId)
        } catch {
            // Keep going with the generated id if Keychain write fails.
        }
        return newId
    }
}
