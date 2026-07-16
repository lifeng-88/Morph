import SwiftUI

struct BSideView: View {
    let url: URL

    @EnvironmentObject private var bSideManager: BSideManager
    @StateObject private var webViewModel: MorphH5WebViewModel
    @State private var consentGranted = AIDataConsentManager.hasGranted
    @State private var showConsentSheet = false

    init(url: URL) {
        self.url = url
        let viewModel = MorphH5Preloader.takeViewModel(for: url) ?? MorphH5WebViewModel(pageURL: url)
        _webViewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()

            if consentGranted {
                webContent
            } else {
                consentPlaceholder
            }
        }
        .fullScreenCover(isPresented: $showConsentSheet) {
            AIDataConsentSheet(
                showsDecline: true,
                onGrant: {
                    consentGranted = true
                    showConsentSheet = false
                },
                onDecline: {
                    showConsentSheet = false
                    bSideManager.switchToNative()
                }
            )
            .interactiveDismissDisabled()
        }
        .onAppear {
            if !consentGranted {
                showConsentSheet = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .morphAIDataConsentRequired)) { _ in
            if !consentGranted {
                showConsentSheet = true
            }
        }
    }

    @ViewBuilder
    private var webContent: some View {
        ZStack {
            MorphH5WebView(viewModel: webViewModel)
                .opacity(webViewModel.isReady ? 1 : 0.15)
                .animation(.easeOut(duration: 0.2), value: webViewModel.isReady)
                .ignoresSafeArea(edges: .bottom)

            if !webViewModel.isReady, webViewModel.errorMessage == nil {
                ProgressView()
                    .tint(MorphColors.primary)
                    .scaleEffect(1.2)
            }

            if let errorMessage = webViewModel.errorMessage {
                errorOverlay(message: errorMessage)
            }
        }
    }

    private var consentPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 42))
                .foregroundStyle(MorphColors.primary)
            Text(L10n.aiConsentBlocked)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(MorphColors.onSurfaceVariant)

            Text(message)
                .font(MorphFont.bodyMD())
                .foregroundStyle(MorphColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                webViewModel.reload()
            } label: {
                Text(L10n.retry)
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.onPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(MorphGradient.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MorphColors.backgroundDeep.opacity(0.92))
    }
}

struct AppLaunchLoadingView: View {
    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()
            ProgressView()
                .tint(MorphColors.primary)
                .scaleEffect(1.2)
        }
    }
}

#Preview {
    BSideView(url: URL(string: "https://glamvid.xin/h5/landing?channel=IOS10065")!)
        .environmentObject(BSideManager.shared)
}
