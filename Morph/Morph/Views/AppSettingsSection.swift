import SwiftUI
import UIKit

struct AppSettingsSection: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var versionTapCount = 0
    @State private var lastVersionTapAt: Date?
    @State private var showDevIdCopiedAlert = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
                Button {
                    handleVersionRowTap()
                } label: {
                    settingsRow(title: L10n.settingsVersion, value: appVersion)
                }
                .buttonStyle(.plain)
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
                    .fullWidthRowTapArea()
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
        .alert(L10n.settingsDevIdCopiedTitle, isPresented: $showDevIdCopiedAlert) {
            Button(L10n.done, role: .cancel) {}
        } message: {
            Text(L10n.settingsDevIdCopiedMessage)
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
        .fullWidthRowTapArea()
    }

    private func handleVersionRowTap() {
        let now = Date()
        if let lastVersionTapAt, now.timeIntervalSince(lastVersionTapAt) > 2 {
            versionTapCount = 0
        }
        lastVersionTapAt = now
        versionTapCount += 1

        guard versionTapCount >= 10 else { return }
        versionTapCount = 0
        lastVersionTapAt = nil

        Task {
            let devId = await MorphDeviceManager.shared.getDeviceId()
            await MainActor.run {
                UIPasteboard.general.string = devId
                showDevIdCopiedAlert = true
            }
        }
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
