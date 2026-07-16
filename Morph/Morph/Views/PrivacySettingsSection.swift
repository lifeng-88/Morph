import SwiftUI

struct PrivacySettingsSection: View {
    @State private var showPrivacyPolicy = false
    @State private var showRevokeAlert = false
    @State private var consentGranted = AIDataConsentManager.hasGranted

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(MorphColors.primary)
                Text(L10n.privacySectionTitle)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
            }

            VStack(spacing: 0) {
                Button {
                    showPrivacyPolicy = true
                } label: {
                    settingsRow(
                        title: L10n.privacyPolicyTitle,
                        trailing: Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MorphColors.onSurfaceVariant)
                    )
                }
                .buttonStyle(.plain)

                divider

                settingsRow(
                    title: L10n.aiConsentStatusTitle,
                    trailing: Text(consentGranted ? L10n.aiConsentStatusGranted : L10n.aiConsentStatusNotGranted)
                        .font(MorphFont.labelMD())
                        .foregroundStyle(consentGranted ? Color.green : MorphColors.onSurfaceVariant)
                )

                if consentGranted {
                    divider
                    Button {
                        showRevokeAlert = true
                    } label: {
                        settingsRow(
                            title: L10n.aiConsentRevoke,
                            trailing: Image(systemName: "xmark.circle")
                                .foregroundStyle(MorphColors.primary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .glassPanel(cornerRadius: 16)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert(L10n.aiConsentRevokeTitle, isPresented: $showRevokeAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.aiConsentRevokeConfirm, role: .destructive) {
                AIDataConsentManager.revoke()
                consentGranted = false
            }
        } message: {
            Text(L10n.aiConsentRevokeMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .morphAIDataConsentGranted)) { _ in
            consentGranted = true
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(MorphColors.separator)
            .frame(height: 1)
    }

    private func settingsRow<T: View>(title: String, trailing: T) -> some View {
        HStack {
            Text(title)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurface)
            Spacer()
            trailing
        }
        .padding(.vertical, 14)
        .fullWidthRowTapArea()
    }
}
