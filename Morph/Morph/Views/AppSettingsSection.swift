import SwiftUI

struct AppSettingsSection: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(MorphColors.secondary)
                Text(L10n.settingsGeneral)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
            }

            VStack(spacing: 0) {
                settingsRow(title: L10n.settingsVersion, value: appVersion)
                divider
                Button {
                    restorePurchases()
                } label: {
                    HStack {
                        Text(L10n.settingsRestorePurchases)
                            .font(MorphFont.bodyMD())
                            .foregroundStyle(MorphColors.onSurface)
                        Spacer()
                        if isRestoring {
                            ProgressView().tint(MorphColors.primary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(MorphColors.primary)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)
            }
        }
        .padding(20)
        .glassPanel(cornerRadius: 16)
        .alert(L10n.settingsRestoreTitle, isPresented: $showRestoreAlert) {
            Button(L10n.done, role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(MorphColors.separator)
            .frame(height: 1)
    }

    private func settingsRow(title: String, value: String, valueColor: Color = MorphColors.onSurfaceVariant) -> some View {
        HStack {
            Text(title)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurface)
            Spacer()
            Text(value)
                .font(MorphFont.labelMD())
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 14)
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            let result = await storeManager.restorePurchases()
            isRestoring = false
            switch result {
            case .recovered(let coins):
                restoreMessage = L10n.coinStorePurchaseSuccessMessage(coins)
            case .synced:
                restoreMessage = L10n.settingsRestoreMessage
            case .failed(let message):
                restoreMessage = message
            }
            showRestoreAlert = true
        }
    }
}
