import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()
            ParticleBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                tabContent
                if appState.selectedTemplate == nil && appState.selectedGalleryItem == nil {
                    MorphBottomNav(selectedTab: $appState.selectedTab)
                }
            }
        }
        .task {
            await storeManager.processUnfinishedTransactions()
        }
        .onChange(of: storeManager.pendingCoinGrant) { _, coins in
            guard let coins else { return }
            appState.grantPurchasedCoins(coins)
            storeManager.consumePendingCoinGrant()
        }
        .fullScreenCover(isPresented: $appState.isProcessing) {
            ProcessingView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showCoinStore) {
            CoinStoreSheet()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.showAIDataConsent) {
            AIDataConsentSheet(
                onGrant: { appState.grantAIDataConsentAndContinue() },
                onDecline: { appState.declineAIDataConsent() }
            )
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
        case .home:
            HomeView()
        case .templates:
            TemplatesView()
        case .draw:
            DrawingView()
        case .my:
            MyGalleryView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(StoreManager.shared)
        .environmentObject(LanguageManager.shared)
}
