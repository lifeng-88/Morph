import SwiftUI

struct BSideView: View {
    let url: URL

    @EnvironmentObject private var bSideManager: BSideManager
    @StateObject private var webViewModel: MorphH5WebViewModel
    @State private var consentGranted = AIDataConsentManager.hasGranted
    @State private var showConsentSheet = false

    init(url: URL) {
        self.url = url
        // 全局唯一 B 面 ViewModel，禁止每次 init 新建 WKWebView
        _webViewModel = StateObject(wrappedValue: MorphH5Preloader.viewModel(for: url))
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
            // 确保使用最新 URL，且不会因 SwiftUI 重建而新建 WebView
            _ = MorphH5Preloader.viewModel(for: url)
            webViewModel.loadIfNeeded()
            if !consentGranted {
                showConsentSheet = true
            }
        }
        .onChange(of: url) { _, newURL in
            _ = MorphH5Preloader.viewModel(for: newURL)
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
            // WebView 本身不绑定 isReady，避免 UIViewRepresentable 反馈环
            MorphH5WebView(viewModel: webViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            if !webViewModel.isReady, webViewModel.errorMessage == nil {
                BSideLoadingOverlay()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let errorMessage = webViewModel.errorMessage {
                errorOverlay(message: errorMessage)
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.28), value: webViewModel.isReady)
        .animation(.easeOut(duration: 0.2), value: webViewModel.errorMessage)
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

/// B 面 H5 加载中遮罩（叠在 WebView 上，就绪后淡出）。
struct BSideLoadingOverlay: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            MorphColors.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(MorphColors.primary.opacity(0.12))
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulse ? 1.08 : 0.92)

                    ProgressView()
                        .tint(MorphColors.primary)
                        .scaleEffect(1.25)
                }

                Text(L10n.loading)
                    .font(MorphFont.labelMD())
                    .foregroundStyle(MorphColors.onSurfaceVariant)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct AppLaunchLoadingView: View {
    var body: some View {
        BSideLoadingOverlay()
    }
}

#Preview {
    BSideView(url: URL(string: "https://glamvid.xin/h5/landing?channel=IOS10065")!)
        .environmentObject(BSideManager.shared)
}
