import Combine
import SwiftUI
import WebKit

@MainActor
final class MorphH5WebViewModel: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?

    private(set) var pageURL: URL
    private(set) lazy var bridge = MorphH5Bridge(viewModel: self)
    private(set) lazy var webView: WKWebView = makeWebView()

    private var didLoad = false
    private var readyFallbackWorkItem: DispatchWorkItem?
    private var loadSequence = 0
    private var isRecoveringProcess = false

    private static let sharedProcessPool = WKProcessPool()
    private static let readyFallbackDelay: TimeInterval = 2.5

    init(pageURL: URL) {
        self.pageURL = pageURL
        MorphH5Config.configure(pageURL: pageURL)
    }

    func replacePageURL(_ url: URL) {
        guard pageURL != url else { return }
        pageURL = url
        MorphH5Config.configure(pageURL: url)
        didLoad = false
        loadIfNeeded()
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        MorphH5PaymentManager.shared.startListening()
        load()
        Task {
            await MorphAFManager.shared.initAFAsync(channelId: MorphH5Config.channel)
        }
    }

    func reload() {
        didLoad = true
        load()
        Task {
            await MorphAFManager.shared.initAFAsync(channelId: MorphH5Config.channel)
        }
    }

    func markReady() {
        readyFallbackWorkItem?.cancel()
        isRecoveringProcess = false
        if errorMessage != nil { errorMessage = nil }
        if !isReady { isReady = true }
    }

    func fail(_ message: String) {
        readyFallbackWorkItem?.cancel()
        if isReady { isReady = false }
        if errorMessage != message { errorMessage = message }
    }

    func navigationFinished() {
        markReady()
    }

    /// 异步恢复，避免在 WebKit terminate 回调栈上同步 reload 导致栈溢出。
    func handleWebContentProcessTermination() {
        guard !isRecoveringProcess else { return }
        isRecoveringProcess = true
        print("⚠️ [H5] WebContent process terminated — scheduling reload")
        DispatchQueue.main.async { [weak self] in
            self?.reload()
        }
    }

    private func load() {
        readyFallbackWorkItem?.cancel()
        loadSequence += 1
        let sequence = loadSequence

        if isReady { isReady = false }
        if errorMessage != nil { errorMessage = nil }

        #if DEBUG
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        #else
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
        #endif

        webView.load(URLRequest(url: pageURL, cachePolicy: cachePolicy, timeoutInterval: 15))

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.loadSequence == sequence, !self.isReady else { return }
            self.markReady()
        }
        readyFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyFallbackDelay, execute: workItem)
    }

    private func makeWebView() -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(bridge, name: MorphH5Bridge.messageName)

        let configuration = WKWebViewConfiguration()
        configuration.processPool = Self.sharedProcessPool
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.setURLSchemeHandler(
            MorphMediaCacheSchemeHandler(),
            forURLScheme: MorphMediaCacheSchemeHandler.scheme
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        MorphH5Config.configureWebViewInspectability(webView)
        webView.navigationDelegate = bridge
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        return webView
    }
}

/// 不用 @ObservedObject，避免 isReady 变更触发 updateUIView 反馈环导致栈溢出。
struct MorphH5WebView: UIViewRepresentable {
    let viewModel: MorphH5WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        viewModel.loadIfNeeded()
        return viewModel.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 故意留空：不要在这里改 frame / 约束 / 重新 addSubview
    }
}
