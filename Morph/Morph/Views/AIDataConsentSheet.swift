import SwiftUI

struct AIDataConsentSheet: View {
    var showsDecline: Bool = true
    var onGrant: () -> Void
    var onDecline: (() -> Void)?

    @State private var showPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    disclosureCard(
                        title: L10n.aiConsentDataTitle,
                        body: L10n.aiConsentDataBody
                    )
                    disclosureCard(
                        title: L10n.aiConsentRecipientTitle,
                        body: L10n.aiConsentRecipientBody
                    )
                    disclosureCard(
                        title: L10n.aiConsentPurposeTitle,
                        body: L10n.aiConsentPurposeBody
                    )
                    disclosureCard(
                        title: L10n.aiConsentRetentionTitle,
                        body: L10n.aiConsentRetentionBody
                    )

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                            Text(L10n.aiConsentPrivacyLink)
                        }
                        .font(MorphFont.labelMD())
                        .foregroundStyle(MorphColors.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(MorphColors.background.ignoresSafeArea())
            .navigationTitle(L10n.aiConsentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDecline, let onDecline {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.aiConsentDecline) {
                            onDecline()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    GradientButton(
                        title: L10n.aiConsentAgree,
                        icon: "checkmark.shield"
                    ) {
                        AIDataConsentManager.grant()
                        onGrant()
                    }
                    .padding(.horizontal, 20)

                    Text(L10n.aiConsentFootnote)
                        .font(MorphFont.labelSM())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(.ultraThinMaterial)
                .background(MorphColors.background.opacity(0.92))
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 36))
                .foregroundStyle(MorphColors.primary)
            Text(L10n.aiConsentSubtitle)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func disclosureCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MorphFont.headlineMD())
                .foregroundStyle(MorphColors.onSurface)
            Text(body)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }
}
