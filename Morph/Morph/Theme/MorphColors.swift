import SwiftUI
import UIKit

enum MorphColors {
    static let background = morphColor(light: "F6F3FC", dark: "131125")
    static let backgroundDeep = morphColor(light: "EFEBF8", dark: "0D0B1F")
    static let surface = morphColor(light: "FFFFFF", dark: "131125")
    static let surfaceContainer = morphColor(light: "FFFFFF", dark: "1F1D32")
    static let surfaceContainerLow = morphColor(light: "F9F7FD", dark: "1B192E")
    static let surfaceContainerHigh = morphColor(light: "EDE9F5", dark: "2A273D")
    static let surfaceContainerLowest = morphColor(light: "F3F0FA", dark: "0E0C20")
    static let surfaceVariant = morphColor(light: "CFC8DE", dark: "353248")

    static let primary = morphColor(light: "D93652", dark: "FFB3B5")
    static let primaryContainer = morphColor(light: "E84561", dark: "FF5167")
    static let onPrimary = morphColor(light: "FFFFFF", dark: "680019")

    static let secondary = morphColor(light: "8E32AD", dark: "E9B3FF")
    static let secondaryContainer = morphColor(light: "7D01B1", dark: "7D01B1")

    static let tertiary = morphColor(light: "0E7F9A", dark: "68D3FF")
    static let tertiaryContainer = morphColor(light: "139CC7", dark: "139CC7")

    static let onSurface = morphColor(light: "1A1428", dark: "E4DFFC")
    static let onSurfaceVariant = morphColor(light: "534766", dark: "E6BCBD")
    static let onBackground = morphColor(light: "1A1428", dark: "E4DFFC")

    static let success = morphColor(light: "15803D", dark: "4ADE80")

    static let glassFill = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.05) : UIColor.white.withAlphaComponent(0.82)
    }

    static let glassBorder = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.1) : UIColor.black.withAlphaComponent(0.06)
    }

    static let separator = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.08) : UIColor.black.withAlphaComponent(0.07)
    }

    static let subtleFill = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.03) : UIColor.black.withAlphaComponent(0.04)
    }

    /// Modal backdrop
    static let scrim = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.45) : UIColor.black.withAlphaComponent(0.28)
    }

    /// Dim overlay on canvas / loading
    static let overlay = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.55) : UIColor.black.withAlphaComponent(0.32)
    }

    static let overlayHeavy = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.6) : UIColor.black.withAlphaComponent(0.4)
    }

    /// Floating toolbar / dock chip background
    static let floatingFill = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.35) : UIColor.white.withAlphaComponent(0.92)
    }

    static let chromeStroke = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.18) : UIColor.black.withAlphaComponent(0.08)
    }

    static let chromeAccentStroke = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.25) : UIColor.black.withAlphaComponent(0.06)
    }

    static let pullIndicator = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.2) : UIColor.black.withAlphaComponent(0.14)
    }

    static let elevatedShadow = morphDynamicColor { isDark in
        isDark ? UIColor.clear : UIColor.black.withAlphaComponent(0.1)
    }

    static let imageBadgeFill = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.45) : UIColor.black.withAlphaComponent(0.38)
    }

    static let highlightFill = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.2) : UIColor.black.withAlphaComponent(0.08)
    }

    static let labelShadow = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.45) : UIColor.clear
    }

    static let onImage = Color.white

    static let imageGradientEnd = morphDynamicColor { isDark in
        isDark ? UIColor.black.withAlphaComponent(0.8) : UIColor.black.withAlphaComponent(0.55)
    }

    /// Canvas overlay chips (fullscreen, restore)
    static let canvasChipForeground = morphColor(light: "D93652", dark: "FFFFFF")

    static let canvasChipFill = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.12) : UIColor.white.withAlphaComponent(0.96)
    }

    static let canvasStroke = morphDynamicColor { isDark in
        isDark
            ? UIColor(red: 217/255, green: 54/255, blue: 82/255, alpha: 0.25)
            : UIColor.black.withAlphaComponent(0.1)
    }

    static let canvasShadow = morphDynamicColor { isDark in
        isDark
            ? UIColor(red: 217/255, green: 54/255, blue: 82/255, alpha: 0.12)
            : UIColor.black.withAlphaComponent(0.08)
    }

    static let swatchBorder = morphDynamicColor { isDark in
        isDark ? UIColor.white.withAlphaComponent(0.25) : UIColor.black.withAlphaComponent(0.14)
    }

    static let disabledControl = morphDynamicColor { isDark in
        isDark
            ? UIColor(red: 230/255, green: 188/255, blue: 189/255, alpha: 0.4)
            : UIColor(red: 83/255, green: 71/255, blue: 102/255, alpha: 0.38)
    }
}

private func morphColor(light: String, dark: String) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

private func morphDynamicColor(_ provider: @escaping (Bool) -> UIColor) -> Color {
    Color(UIColor { traits in
        provider(traits.userInterfaceStyle == .dark)
    })
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8) & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
