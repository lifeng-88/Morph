import SwiftUI

@main
struct MorphApp: App {
    @UIApplicationDelegateAdaptor(MorphPushAppDelegate.self) private var pushDelegate
    @StateObject private var appState = AppState()
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var bSideManager = BSideManager.shared
    @State private var showLaunchAIConsent = !AIDataConsentManager.hasGranted
    @State private var didStartBootstrap = false

    var body: some Scene {
        WindowGroup {
            Group {
                switch bSideManager.phase {
                case .loading:
                    AppLaunchLoadingView()
                case .native:
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(languageManager)
                        .environmentObject(storeManager)
                        .environmentObject(bSideManager)
                        .environment(\.locale, languageManager.current.locale)
                        .id(languageManager.refreshToken)
                case .web(let url):
                    BSideView(url: url)
                        .environmentObject(bSideManager)
                        // 稳定身份，避免 phase 刷新时反复销毁/创建 WKWebView
                        .id("bside-web")
                }
            }
            .preferredColorScheme(appearanceManager.current.colorScheme)
            .task {
                guard !showLaunchAIConsent else { return }
                startBootstrapIfNeeded()
            }
            .fullScreenCover(isPresented: $showLaunchAIConsent) {
                AIDataConsentSheet(
                    showsDecline: true,
                    onGrant: {
                        showLaunchAIConsent = false
                        startBootstrapIfNeeded()
                    },
                    onDecline: {
                        showLaunchAIConsent = false
                        startBootstrapIfNeeded()
                    }
                )
                .interactiveDismissDisabled()
            }
        }
    }

    private func startBootstrapIfNeeded() {
        guard !didStartBootstrap else { return }
        didStartBootstrap = true
        Task {
            await bSideManager.bootstrapFromRemote()
        }
    }
}
