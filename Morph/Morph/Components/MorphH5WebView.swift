import Combine
import SwiftUI
import WebKit

@MainActor
final class MorphH5WebViewModel: ObservableObject {
    @Published var isReady = false
    @Published var errorMessage: String?

    let pageURL: URL
    private(set) lazy var bridge = MorphH5Bridge(viewModel: self)
    private(set) lazy var webView: WKWebView = makeWebView()

    private var didLoad = false
    private var keyboardObservers: [NSObjectProtocol] = []
    private var readyFallbackWorkItem: DispatchWorkItem?
    private var loadSequence = 0

    init(pageURL: URL) {
        self.pageURL = pageURL
        MorphH5Config.configure(pageURL: pageURL)
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        Task {
            await MorphAFManager.shared.initAFAsync(channelId: MorphH5Config.channel)
        }
        MorphH5PaymentManager.shared.startListening()
        load()
    }

    func reload() {
        isReady = false
        errorMessage = nil
        Task {
            await MorphAFManager.shared.initAFAsync(channelId: MorphH5Config.channel)
        }
        load()
    }

    func markReady() {
        readyFallbackWorkItem?.cancel()
        isReady = true
        errorMessage = nil
    }

    func fail(_ message: String) {
        readyFallbackWorkItem?.cancel()
        isReady = false
        errorMessage = message
    }

    func navigationFinished() {
        let sequence = loadSequence
        readyFallbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.loadSequence == sequence, !self.isReady else { return }
            self.markReady()
        }
        readyFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    private func load() {
        errorMessage = nil
        isReady = false
        readyFallbackWorkItem?.cancel()
        loadSequence += 1

        #if DEBUG
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        #else
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
        #endif

        webView.load(URLRequest(url: pageURL, cachePolicy: cachePolicy, timeoutInterval: 15))
    }

    private func makeWebView() -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(bridge, name: MorphH5Bridge.messageName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.setURLSchemeHandler(MorphMediaCacheSchemeHandler(), forURLScheme: MorphMediaCacheSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        MorphH5Config.configureWebViewInspectability(webView)
        webView.navigationDelegate = bridge
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.keyboardDismissMode = .none
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        installKeyboardScrollGuard(for: webView)
        return webView
    }

    private func installKeyboardScrollGuard(for webView: WKWebView) {
        let center = NotificationCenter.default
        let notifications: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardDidChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification
        ]

        keyboardObservers = notifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak webView] _ in
                guard let webView else { return }
                webView.scrollView.contentInset = .zero
                webView.scrollView.scrollIndicatorInsets = .zero
                webView.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }
}

struct MorphH5WebView: UIViewRepresentable {
    @ObservedObject var viewModel: MorphH5WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        viewModel.loadIfNeeded()
        return viewModel.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
