import SwiftUI
import WebKit

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared

    private var privacyResourceName: String {
        Self.resourceName(for: languageManager.current)
    }

    var body: some View {
        NavigationStack {
            BundledPrivacyWebView(resourceName: privacyResourceName)
                .background(MorphColors.background.ignoresSafeArea())
                .navigationTitle(L10n.privacyPolicyTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.done) { dismiss() }
                    }
                }
        }
    }

    static func resourceName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "morph-privacy"
        case .simplifiedChinese, .traditionalChinese:
            return "morph-privacy-zh"
        case .system:
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return code.hasPrefix("zh") ? "morph-privacy-zh" : "morph-privacy"
        }
    }
}

private struct BundledPrivacyWebView: UIViewRepresentable {
    let resourceName: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.loadPrivacy(resourceName: resourceName, into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.loadPrivacy(resourceName: resourceName, into: uiView)
    }

    final class Coordinator {
        private var loadedResourceName: String?

        func loadPrivacy(resourceName: String, into webView: WKWebView) {
            guard loadedResourceName != resourceName else { return }
            loadedResourceName = resourceName

            let candidates = [resourceName, "morph-privacy"]
            for name in candidates {
                if let url = Bundle.main.url(forResource: name, withExtension: "html") {
                    let folder = url.deletingLastPathComponent()
                    webView.loadFileURL(url, allowingReadAccessTo: folder)
                    return
                }
                if let url = Bundle.main.url(forResource: name, withExtension: "html", subdirectory: "Resources") {
                    let folder = url.deletingLastPathComponent()
                    webView.loadFileURL(url, allowingReadAccessTo: folder)
                    return
                }
                if let path = Bundle.main.path(forResource: name, ofType: "html"),
                   let html = try? String(contentsOfFile: path, encoding: .utf8) {
                    webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: (path as NSString).deletingLastPathComponent))
                    return
                }
            }

            webView.loadHTMLString(
                """
                <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
                <style>body{font-family:-apple-system,sans-serif;padding:20px;line-height:1.6;}</style></head>
                <body><p>Privacy policy file could not be loaded. Please contact support@glamvid.xin</p></body></html>
                """,
                baseURL: nil
            )
        }
    }
}
