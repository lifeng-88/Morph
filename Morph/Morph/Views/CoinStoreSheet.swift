import SwiftUI

struct CoinStoreSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPurchaseError = false
    @State private var showPurchaseSuccess = false
    @State private var purchasedCoins = 0
    @State private var isRestoring = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

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
                        footerSection
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
        .task {
            await storeManager.loadProducts(force: true)
        }
        .alert(L10n.coinStorePurchaseFailed, isPresented: $showPurchaseError) {
            Button(L10n.done, role: .cancel) {
                storeManager.clearError()
            }
        } message: {
            Text(storeManager.lastError ?? "")
        }
        .alert(L10n.coinStorePurchaseSuccessTitle, isPresented: $showPurchaseSuccess) {
            Button(L10n.done) {
                dismiss()
            }
        } message: {
            Text(L10n.coinStorePurchaseSuccessMessage(purchasedCoins))
        }
        .alert(L10n.settingsRestoreTitle, isPresented: $showRestoreAlert) {
            Button(L10n.done, role: .cancel) {}
        } message: {
            Text(restoreMessage)
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
                .disabled(isPackDisabled(pack))
            }

            if storeManager.didFinishLoading && storeManager.products.isEmpty {
                VStack(spacing: 12) {
                    Text(L10n.coinStoreProductsUnavailable)
                        .font(MorphFont.labelSM())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button(L10n.coinStoreRetry) {
                        Task { await storeManager.loadProducts(force: true) }
                    }
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.primary)
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 12) {
            Button {
                restorePurchases()
            } label: {
                HStack(spacing: 8) {
                    if isRestoring {
                        ProgressView().tint(MorphColors.primary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(L10n.coinStoreRestore)
                        .font(MorphFont.labelMD())
                }
                .foregroundStyle(MorphColors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || storeManager.isLoading)

            Text(L10n.coinStoreConsumableNotice)
                .font(MorphFont.labelSM())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    private func isPackDisabled(_ pack: CoinPack) -> Bool {
        if storeManager.isLoading || isRestoring { return true }
        if let purchasingID = storeManager.purchasingProductID, purchasingID != pack.productID {
            return true
        }
        if !storeManager.didFinishLoading { return true }
        return !storeManager.isProductAvailable(pack.productID)
    }

    private func packRow(_ pack: CoinPack) -> some View {
        let isAvailable = storeManager.isProductAvailable(pack.productID)
        let isPurchasing = storeManager.purchasingProductID == pack.productID

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(L10n.coins(pack.totalCoins))
                        .font(MorphFont.headlineMD())
                        .foregroundStyle(isAvailable ? MorphColors.onSurface : MorphColors.onSurfaceVariant)
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
                HStack(spacing: 6) {
                    Text(storeManager.displayPrice(for: pack))
                        .font(MorphFont.labelSM())
                        .foregroundStyle(MorphColors.onSurfaceVariant)
                    if storeManager.usesFallbackPrice(for: pack) {
                        Text(L10n.coinStoreEstimatedPrice)
                            .font(MorphFont.labelSM())
                            .foregroundStyle(MorphColors.onSurfaceVariant.opacity(0.7))
                    }
                }
            }
            Spacer()
            if isPurchasing {
                ProgressView().tint(MorphColors.primary)
            } else {
                Image(systemName: isAvailable ? "plus.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(isAvailable ? MorphColors.primary : MorphColors.onSurfaceVariant.opacity(0.5))
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 16)
        .neonBorder(MorphColors.secondary.opacity(isAvailable ? 0.2 : 0.08), cornerRadius: 16)
        .opacity(isAvailable ? 1 : 0.72)
    }

    private func purchase(_ pack: CoinPack) {
        Task {
            switch await storeManager.purchase(productID: pack.productID) {
            case .success(let coins):
                purchasedCoins = coins
                appState.grantPurchasedCoins(coins)
                showPurchaseSuccess = true
            case .pending:
                showPurchaseError = true
            case .failed:
                showPurchaseError = true
            case .cancelled:
                break
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
                purchasedCoins = coins
                showPurchaseSuccess = true
            case .synced:
                restoreMessage = L10n.settingsRestoreMessage
                showRestoreAlert = true
            case .failed(let message):
                showPurchaseError = true
                storeManager.lastError = message
            }
        }
    }
}
