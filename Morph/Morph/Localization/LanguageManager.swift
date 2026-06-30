import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant")
        }
    }

    var bundleCode: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        }
    }

    var icon: String {
        switch self {
        case .system: return "globe"
        case .english: return "character.textbox"
        case .simplifiedChinese: return "character"
        case .traditionalChinese: return "character.book.closed"
        }
    }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
            refreshToken = UUID()
        }
    }

    @Published private(set) var refreshToken = UUID()

    private static let storageKey = "morph.app.language"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let language = AppLanguage(rawValue: raw) {
            current = language
        } else {
            current = .system
        }
    }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        current = language
    }

    func localizedString(_ key: String) -> String {
        let bundle = localizationBundle
        let value = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        return value == key ? fallbackString(for: key) : value
    }

    private var localizationBundle: Bundle {
        if let code = current.bundleCode,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    private func fallbackString(for key: String) -> String {
        guard current != .english,
              let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }
}
