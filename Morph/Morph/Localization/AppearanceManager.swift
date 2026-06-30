import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published private(set) var current: AppAppearance {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "morph.app.appearance"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let appearance = AppAppearance(rawValue: raw) {
            current = appearance
        } else {
            current = .dark
        }
    }

    func select(_ appearance: AppAppearance) {
        guard appearance != current else { return }
        current = appearance
    }
}
