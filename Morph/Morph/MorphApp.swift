import SwiftUI

@main
struct MorphApp: App {
    @UIApplicationDelegateAdaptor(MorphPushAppDelegate.self) private var pushDelegate
    @StateObject private var appState = AppState()
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var bSideManager = BSideManager.shared

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
                }
            }
            .preferredColorScheme(appearanceManager.current.colorScheme)
            .task {
                await bSideManager.bootstrapFromRemote()
            }
        }
    }
}
