import SwiftUI

struct LanguageSettingsSection: View {
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundStyle(MorphColors.tertiary)
                Text(L10n.settingsLanguage)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
            }

            Text(L10n.settingsLanguageHint)
                .font(MorphFont.labelSM())
                .foregroundStyle(MorphColors.onSurfaceVariant)

            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { language in
                    languageRow(language)
                }
            }
        }
        .padding(20)
        .glassPanel(cornerRadius: 16)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let isSelected = languageManager.current == language

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                languageManager.select(language)
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
                    Image(systemName: language.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? MorphColors.primary : MorphColors.onSurfaceVariant)
                }

                Text(language.displayName)
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
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguageSettingsSection()
        .environmentObject(LanguageManager.shared)
        .padding()
        .background(MorphColors.background)
}
