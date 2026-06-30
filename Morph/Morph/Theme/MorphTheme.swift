import SwiftUI

enum MorphFont {
    static func headlineXL() -> Font { .system(size: 48, weight: .heavy, design: .rounded) }
    static func headlineLG() -> Font { .system(size: 32, weight: .bold, design: .rounded) }
    static func headlineLGMobile() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func headlineMD() -> Font { .system(size: 24, weight: .semibold, design: .rounded) }
    static func bodyLG() -> Font { .system(size: 18, weight: .regular) }
    static func bodyMD() -> Font { .system(size: 16, weight: .regular) }
    static func labelMD() -> Font { .system(size: 14, weight: .semibold) }
    static func labelSM() -> Font { .system(size: 12, weight: .medium) }
}

struct MorphGradient {
    static let primary = LinearGradient(
        colors: [MorphColors.primaryContainer, MorphColors.secondaryContainer],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pinkPurple = LinearGradient(
        colors: [MorphColors.primary, MorphColors.secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cyberLine = LinearGradient(
        colors: [.clear, MorphColors.primary, .clear],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(MorphColors.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(MorphColors.glassBorder, lineWidth: 1)
            )
            .shadow(
                color: MorphColors.elevatedShadow,
                radius: colorScheme == .light ? 10 : 0,
                y: colorScheme == .light ? 3 : 0
            )
    }
}

struct NeonBorder: ViewModifier {
    var color: Color
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.3), radius: 8)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }

    func neonBorder(_ color: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(NeonBorder(color: color, cornerRadius: cornerRadius))
    }
}
