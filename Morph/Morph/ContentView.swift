import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

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
        .environmentObject(LanguageManager.shared)
}
