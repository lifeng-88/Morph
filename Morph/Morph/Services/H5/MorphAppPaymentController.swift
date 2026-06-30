//
//  MorphAppPaymentController.swift
//  App
//

import UIKit
import WebKit

final class MorphAppPaymentController: UIViewController, WKNavigationDelegate {
    private let url: URL
    private let onClose: () -> Void
    private var didNotifyClose = false
    private var progressObservation: NSKeyValueObservation?

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        MorphH5Config.configureWebViewInspectability(webView)
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .bar)
        view.progressTintColor = UIColor(red: 0.94, green: 0.22, blue: 0.78, alpha: 1)
        view.trackTintColor = .clear
        return view
    }()

    init(url: URL, onClose: @escaping () -> Void) {
        self.url = url
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureLayout()
        observeProgress()
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    private func configureLayout() {
        let header = UIView()
        header.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
        header.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Payment"
        title.textColor = .white
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        webView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        header.addSubview(title)
        header.addSubview(closeButton)
        view.addSubview(webView)
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),

            title.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            title.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),

            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: title.centerYAnchor),

            progressView.topAnchor.constraint(equalTo: header.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func observeProgress() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressView.setProgress(progress, animated: true)
            self.progressView.isHidden = progress >= 1
        }
    }

    @objc private func closeTapped() {
        notifyCloseAndDismiss()
    }

    private func notifyCloseAndDismiss() {
        guard !didNotifyClose else { return }
        didNotifyClose = true
        onClose()
        dismiss(animated: true)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let navigationURL = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if MorphPaymentRedirectReturnURL.matches(navigationURL) {
            didNotifyClose = true
            MorphPaymentCallbackManager.shared.handle(url: navigationURL)
            dismiss(animated: true)
            decisionHandler(.cancel)
            return
        }

        let scheme = navigationURL.scheme?.lowercased() ?? ""
        if !["http", "https", "about"].contains(scheme) {
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}
