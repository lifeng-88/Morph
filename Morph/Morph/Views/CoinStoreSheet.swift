import SwiftUI

struct CoinStoreSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingPackID: String?
    @State private var showPurchaseError = false

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.backgroundDeep.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        balanceCard
                        if let error = storeManager.lastError {
                            errorBanner(error)
                        }
                        packsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(L10n.coinStoreTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { dismiss() }
                        .foregroundStyle(MorphColors.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await storeManager.loadProducts() }
        .alert(L10n.coinStorePurchaseFailed, isPresented: $showPurchaseError) {
            Button(L10n.done, role: .cancel) {
                storeManager.clearError()
            }
        } message: {
            Text(storeManager.lastError ?? "")
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text(L10n.coinStoreBalance)
                .font(MorphFont.labelMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
            HStack(spacing: 8) {
                Text("\(appState.coins)")
                    .font(MorphFont.headlineLGMobile())
                    .foregroundStyle(MorphColors.primary)
                Text("🪙")
                    .font(.system(size: 28))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassPanel(cornerRadius: 20)
        .neonBorder(MorphColors.primary.opacity(0.3), cornerRadius: 20)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MorphColors.primaryContainer)
            Text(message)
                .font(MorphFont.labelSM())
                .foregroundStyle(MorphColors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                storeManager.clearError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(MorphColors.primary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var packsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.coinStorePacks)
                    .font(MorphFont.headlineMD())
                    .foregroundStyle(MorphColors.onSurface)
                if storeManager.isLoading {
                    ProgressView()
                        .tint(MorphColors.primary)
                }
            }

            ForEach(appState.coinPacks) { pack in
                Button {
                    purchase(pack)
                } label: {
                    packRow(pack)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(purchasingPackID != nil)
            }

            if storeManager.products.isEmpty && !storeManager.isLoading {
                Text(L10n.coinStoreSandboxHint)
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func packRow(_ pack: CoinPack) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(L10n.coins(pack.totalCoins))
                        .font(MorphFont.headlineMD())
                        .foregroundStyle(MorphColors.onSurface)
                    if let bonusLabel = pack.bonusLabel {
                        Text(bonusLabel)
                            .font(MorphFont.labelSM())
                            .foregroundStyle(MorphColors.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MorphColors.tertiary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if pack.isRecommended {
                        Text(L10n.coinStoreRecommended)
                            .font(MorphFont.labelSM())
                            .foregroundStyle(MorphColors.onPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MorphGradient.primary)
                            .clipShape(Capsule())
                    }
                }
                Text(storeManager.displayPrice(for: pack))
                    .font(MorphFont.labelSM())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }
            Spacer()
            if purchasingPackID == pack.id {
                ProgressView().tint(MorphColors.primary)
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(MorphColors.primary)
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 16)
        .neonBorder(MorphColors.secondary.opacity(0.2), cornerRadius: 16)
    }

    private func purchase(_ pack: CoinPack) {
        purchasingPackID = pack.id
        Task {
            if let coins = await storeManager.purchase(productID: pack.productID) {
                appState.purchaseCoins(coins)
                dismiss()
            } else if storeManager.lastError != nil {
                showPurchaseError = true
            }
            purchasingPackID = nil
        }
    }
}
