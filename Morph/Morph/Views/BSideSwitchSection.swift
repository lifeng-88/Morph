import SwiftUI

struct BSideSwitchSection: View {
    @EnvironmentObject private var bSideManager: BSideManager
    @State private var isSwitching = false

    var body: some View {
        if bSideManager.canSwitchToBSide {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(MorphColors.tertiary)
                    Text(L10n.settingsBSideTitle)
                        .font(MorphFont.headlineMD())
                        .foregroundStyle(MorphColors.onSurface)
                }

                Text(L10n.settingsBSideHint)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)

                Button {
                    openBSide()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 18, weight: .semibold))
                        Text(L10n.settingsBSideOpen)
                            .font(MorphFont.labelMD())
                        Spacer()
                        if isSwitching {
                            ProgressView()
                                .tint(MorphColors.onPrimary)
                        }
                    }
                    .foregroundStyle(MorphColors.onPrimary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MorphGradient.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSwitching)
            }
            .padding(20)
            .glassPanel(cornerRadius: 16)
        }
    }

    private func openBSide() {
        isSwitching = true
        Task {
            await bSideManager.switchToBSide()
            isSwitching = false
        }
    }
}

#Preview {
    BSideSwitchSection()
        .environmentObject(BSideManager.shared)
        .padding()
        .background(MorphColors.background)
}
