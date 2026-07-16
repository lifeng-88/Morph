import SwiftUI

struct AppearanceSettingsSection: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "moon.fill")
                    .foregroundStyle(MorphColors.secondary)
                Text(L10n.settingsAppearance)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
            }

            Text(L10n.settingsAppearanceHint)
                .font(MorphFont.labelSM())
                .foregroundStyle(MorphColors.onSurfaceVariant)

            VStack(spacing: 10) {
                ForEach(AppAppearance.allCases) { appearance in
                    appearanceRow(appearance)
                }
            }
        }
        .padding(20)
        .glassPanel(cornerRadius: 16)
    }

    private func appearanceRow(_ appearance: AppAppearance) -> some View {
        let isSelected = appearanceManager.current == appearance

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appearanceManager.select(appearance)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? MorphColors.primary.opacity(0.15) : MorphColors.surfaceContainer)
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? MorphColors.primary.opacity(0.4) : MorphColors.separator, lineWidth: 1)
                        )
                    Image(systemName: appearance.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? MorphColors.primary : MorphColors.onSurfaceVariant)
                }

                Text(appearance.displayName)
                    .font(MorphFont.bodyMD())
                    .foregroundStyle(MorphColors.onSurface)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MorphColors.primary)
                        .shadow(color: MorphColors.primary.opacity(0.4), radius: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? MorphColors.primary.opacity(0.06) : MorphColors.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? MorphColors.primary.opacity(0.35) : MorphColors.separator, lineWidth: 1)
            )
            .fullWidthRowTapArea()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppearanceSettingsSection()
        .padding()
        .background(MorphColors.background)
}
