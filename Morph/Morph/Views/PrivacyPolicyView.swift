import SwiftUI
import WebKit

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BundledPrivacyWebView()
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
}

private struct BundledPrivacyWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        let filename = languageCode.hasPrefix("zh") ? "morph-privacy-zh" : "morph-privacy"
        if let url = Bundle.main.url(forResource: filename, withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
