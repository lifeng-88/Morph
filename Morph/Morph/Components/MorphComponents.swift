import SwiftUI

struct MorphAppBar: View {
    var title: String = "Morph"
    var showBack: Bool = false
    var onBack: (() -> Void)?

    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack {
            if showBack {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MorphColors.primary)
                        .frame(width: 40, height: 40)
                }
            }

            Text(title)
                .font(MorphFont.headlineMD())
                .foregroundStyle(MorphColors.primary)
                .tracking(-0.5)

            Spacer()

            Button {
                appState.showCoinStore = true
            } label: {
                CoinBadge(coins: appState.coins)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(.ultraThinMaterial)
        .background(MorphColors.glassFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MorphColors.separator)
                .frame(height: 1)
        }
        .shadow(color: MorphColors.primary.opacity(0.2), radius: 8, y: 2)
    }
}

struct CoinBadge: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(coins)")
                .font(MorphFont.labelMD())
                .foregroundStyle(MorphColors.primary)
            Text("🪙")
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassPanel(cornerRadius: 20)
    }
}

struct MorphBottomNav: View {
    @Binding var selectedTab: MorphTab

    private let tabItemHeight: CGFloat = 52

    var body: some View {
        HStack {
            ForEach(MorphTab.allCases, id: \.rawValue) { tab in
                Spacer(minLength: 0)
                bottomTabItem(tab)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 24)
        .padding(.horizontal, 8)
        .frame(height: tabItemHeight + 34)
        .background(.ultraThinMaterial)
        .background(MorphColors.glassFill)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MorphColors.separator)
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: MorphColors.elevatedShadow, radius: 12, y: -2)
    }

    @ViewBuilder
    private func bottomTabItem(_ tab: MorphTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))
                Text(tab.localizedTitle)
                    .font(MorphFont.labelSM())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? MorphColors.primary : MorphColors.onSurfaceVariant.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: tabItemHeight)
            .padding(.horizontal, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(MorphColors.primary.opacity(0.1))
                        .overlay(Capsule().stroke(MorphColors.primary.opacity(0.3), lineWidth: 1))
                        .shadow(color: MorphColors.primary.opacity(0.4), radius: 10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(title)
                    .font(MorphFont.headlineMD())
                if let subtitle {
                    Rectangle()
                        .fill(MorphColors.highlightFill)
                        .frame(width: 1, height: 24)
                    Text(subtitle)
                        .font(MorphFont.headlineMD())
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? AnyShapeStyle(MorphGradient.primary) : AnyShapeStyle(MorphColors.surfaceVariant.opacity(0.5)))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isEnabled ? MorphColors.primaryContainer.opacity(0.4) : .clear, radius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(MorphFont.labelMD())
            }
            .foregroundStyle(MorphColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MorphGradient.pinkPurple, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CategoryChip: View {
    let title: String
    var isActive: Bool = false
    var color: Color = MorphColors.tertiary

    var body: some View {
        HStack(spacing: 6) {
            if isActive {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color, radius: 4)
            }
            Text(title)
                .font(MorphFont.labelMD())
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? color : MorphColors.onSurfaceVariant)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MorphColors.surfaceContainer.opacity(0.6))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(isActive ? color : color.opacity(0.3), lineWidth: 1))
    }
}

struct MorphToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(iconColor.opacity(0.3), lineWidth: 1))
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MorphFont.bodyLG())
                    .foregroundStyle(MorphColors.onSurface)
                Text(subtitle)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(isOn ? MorphColors.primary : MorphColors.secondary)
        }
    }
}

struct MorphImageView: View {
    let assetName: String
    var aspectRatio: CGFloat? = nil
    var alignment: Alignment = .center

    var body: some View {
        boundedFillImage(Image(assetName))
    }

    @ViewBuilder
    private func boundedFillImage(_ image: Image) -> some View {
        if let aspectRatio {
            GeometryReader { geo in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                    .clipped()
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            GeometryReader { geo in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                    .clipped()
            }
        }
    }
}

struct MorphPhotoView: View {
    var assetName: String?
    var uiImage: UIImage?
    var aspectRatio: CGFloat? = nil
    var alignment: Alignment = .center

    var body: some View {
        Group {
            if let uiImage {
                boundedFillImage(Image(uiImage: uiImage))
            } else if let assetName {
                boundedFillImage(Image(assetName))
            } else {
                MorphColors.surfaceContainer
            }
        }
    }

    @ViewBuilder
    private func boundedFillImage(_ image: Image) -> some View {
        if let aspectRatio {
            GeometryReader { geo in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                    .clipped()
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            GeometryReader { geo in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                    .clipped()
            }
        }
    }
}

struct GalleryImageView: View {
    let item: GalleryItem
    var aspectRatio: CGFloat? = nil

    var body: some View {
        MorphPhotoView(
            assetName: item.imageAsset,
            uiImage: item.loadUIImage(),
            aspectRatio: aspectRatio
        )
    }
}

struct TransformationInputComparisonView: View {
    var sourceImage: UIImage?
    var sourceAssetName: String?
    var template: TemplateItem?

    var body: some View {
        if sourceImage != nil || template != nil {
            HStack(alignment: .center, spacing: 8) {
                if sourceImage != nil || sourceAssetName != nil {
                    inputThumbCard(
                        label: L10n.sourcePhoto,
                        labelColor: MorphColors.primary,
                        borderColor: MorphColors.primary
                    ) {
                        MorphPhotoView(assetName: sourceAssetName, uiImage: sourceImage)
                    }
                }

                if (sourceImage != nil || sourceAssetName != nil) && template != nil {
                    inputFlowIndicator
                }

                if let template {
                    inputThumbCard(
                        label: L10n.selectedTemplate,
                        labelColor: MorphColors.secondary,
                        borderColor: MorphColors.secondary
                    ) {
                        MorphImageView(assetName: template.imageAsset, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var inputFlowIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MorphColors.primary.opacity(0.85))
            Capsule()
                .fill(MorphColors.primary.opacity(0.35))
                .frame(width: 2, height: 16)
        }
        .frame(width: 28)
    }

    private func inputThumbCard<Content: View>(
        label: String,
        labelColor: Color,
        borderColor: Color,
        @ViewBuilder image: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    image()
                }
                .clipShape(Rectangle())
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, MorphColors.background.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .allowsHitTesting(false)
                }

            Text(label)
                .font(MorphFont.labelSM())
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(MorphColors.surfaceContainer.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor.opacity(0.55), lineWidth: 1)
        )
    }
}

// Legacy alias
typealias AsyncImageView = MorphImageView

extension MorphImageView {
    init(urlString: String, aspectRatio: CGFloat? = nil) {
        self.init(assetName: urlString, aspectRatio: aspectRatio)
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct ParticleBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    private struct ParticleSpec {
        let xFactor: CGFloat
        let size: CGFloat
        let opacity: Double
        let duration: Double
        let delay: Double
    }

    private static let particles: [ParticleSpec] = [
        ParticleSpec(xFactor: 0.08, size: 3, opacity: 0.18, duration: 12, delay: 0.0),
        ParticleSpec(xFactor: 0.17, size: 5, opacity: 0.24, duration: 16, delay: 0.5),
        ParticleSpec(xFactor: 0.26, size: 4, opacity: 0.14, duration: 14, delay: 1.0),
        ParticleSpec(xFactor: 0.35, size: 6, opacity: 0.22, duration: 18, delay: 1.5),
        ParticleSpec(xFactor: 0.44, size: 3, opacity: 0.16, duration: 11, delay: 2.0),
        ParticleSpec(xFactor: 0.53, size: 5, opacity: 0.20, duration: 15, delay: 2.5),
        ParticleSpec(xFactor: 0.62, size: 4, opacity: 0.12, duration: 13, delay: 3.0),
        ParticleSpec(xFactor: 0.71, size: 6, opacity: 0.26, duration: 17, delay: 3.5),
        ParticleSpec(xFactor: 0.80, size: 3, opacity: 0.15, duration: 12, delay: 4.0),
        ParticleSpec(xFactor: 0.89, size: 5, opacity: 0.21, duration: 19, delay: 4.5),
        ParticleSpec(xFactor: 0.95, size: 4, opacity: 0.17, duration: 14, delay: 5.0),
        ParticleSpec(xFactor: 0.50, size: 2, opacity: 0.10, duration: 20, delay: 5.5)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(Self.particles.enumerated()), id: \.offset) { index, particle in
                Circle()
                    .fill(MorphColors.primary.opacity(adjustedOpacity(particle.opacity)))
                    .frame(width: particle.size, height: particle.size)
                    .position(
                        x: geo.size.width * particle.xFactor,
                        y: animate ? -20 : geo.size.height + 20
                    )
                    .animation(
                        .linear(duration: particle.duration)
                        .repeatForever(autoreverses: false)
                        .delay(particle.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }

    private func adjustedOpacity(_ base: Double) -> Double {
        colorScheme == .dark ? base : base * 0.45
    }
}

struct CircuitLinesBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Spacer()
                Rectangle()
                    .fill(MorphGradient.cyberLine)
                    .frame(height: 1)
                    .opacity(colorScheme == .dark ? 0.1 : 0.06)
            }
            Spacer()
        }
    }
}

extension View {
    /// 让 HStack 行内 Spacer 空白区域也能响应点击。
    func fullWidthRowTapArea(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
    }
}
