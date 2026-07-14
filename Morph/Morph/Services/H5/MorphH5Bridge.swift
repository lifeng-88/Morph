//
//  Bridge.swift
//  App
//

import Foundation
import Photos
import PhotosUI
import UIKit
import Vision
import WebKit

final class MorphH5Bridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, PHPickerViewControllerDelegate {
    static let messageName = "syncAppInfo"
    #if DEBUG
    private static let bridgeVersion = "2026-05-15.1"
    private static let diagnosticMethods = [
        "getCapabilities",
        "debugLog",
        "logAnalyticsEvent",
        "getCachedVideoURL",
        "prefetchVideo",
        "getTemplateFeedCache",
        "setTemplateFeedCache",
        "getTemplateDetailCache",
        "setTemplateDetailCache"
    ]
    #endif
    private static let toastViewTag = 92_051_501

    private weak var viewModel: MorphH5WebViewModel?
    private var pendingPhotoRequestId: String?
    private weak var activePaymentBrowser: MorphAppPaymentController?
    private var activePaymentBrowserContext: [String: Any]?
    private var activePaymentRequestId: String?

    init(viewModel: MorphH5WebViewModel) {
        self.viewModel = viewModel
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushPayloadNotification(_:)),
            name: .morphPushPayloadReceived,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePaymentCallbackNotification(_:)),
            name: .morphPaymentCallbackReceived,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePaymentTransactionNotification(_:)),
            name: .morphPaymentTransactionUpdated,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let requestId = body["requestId"] as? String,
            let typeName = body["typeName"] as? String
        else { return }

        switch typeName {
        #if DEBUG
        case "getCapabilities":
            debugLog("call \(typeName)")
            respond(requestId: requestId, result: [
                "bridgeVersion": Self.bridgeVersion,
                "messageName": Self.messageName,
                "typeNames": Self.diagnosticMethods
            ])
        #endif
        case "getAppInfo":
            debugLog("call \(typeName)")
            var result: [String: Any] = [
                "platform": "ios",
                "appName": MorphH5Config.appDisplayName,
                "appVersion": MorphH5Config.appVersion,
                "systemVersion": UIDevice.current.systemVersion,
                "systemLocale": Locale.current.identifier
            ]
            if let privacyURL = MorphH5Config.privacyURL {
                result["privacyURL"] = privacyURL.absoluteString
            }
            #if DEBUG
            result["buildConfiguration"] = MorphH5Config.buildConfigurationLabel
            result["bridgeVersion"] = Self.bridgeVersion
            result["deviceModel"] = UIDevice.current.model
            result["debugTypeNames"] = Self.diagnosticMethods
            #endif
            if let channel = MorphH5Config.channel {
                result["channel"] = channel
            }
            respond(requestId: requestId, result: result)
        case "prepareLoginAttribution":
            debugLog("call \(typeName)")
            let channel = Self.stringParam("channel", from: body)
            Task {
                let result = await MorphAFManager.shared.prepareLoginAttribution(
                    channelId: channel
                )
                await MainActor.run {
                    self.respond(requestId: requestId, result: result)
                }
            }
        case "markLoginCompleted":
            debugLog("call \(typeName)")
            MorphAFManager.shared.markLoginCompleted()
            respond(requestId: requestId, result: ["completed": true])
        case "Ready":
            debugLog("call \(typeName)")
            viewModel?.markReady()
            respond(requestId: requestId, result: ["ready": true])
        case "logAnalyticsEvent":
            debugLog("call \(typeName)")
            let params = Self.params(from: body)
            let eventName = Self.eventNameParam(from: params)
            let eventValues = Self.eventValuesParam(from: params)
            let channel = Self.stringParam("channel", from: body)
            Task {
                let result = await MorphAFManager.shared.logEvent(
                    channelId: channel,
                    eventName: eventName,
                    values: eventValues
                )
                await MainActor.run {
                    if (result["logged"] as? Bool) == true {
                        self.respond(requestId: requestId, result: result)
                    } else {
                        self.respond(requestId: requestId, error: [
                            "code": (result["code"] as? String) ?? "AF_LOG_EVENT_FAILED",
                            "message": (result["message"] as? String) ?? "AppsFlyer logEvent failed."
                        ])
                    }
                }
            }
        #if DEBUG
        case "debugLog":
            if MorphH5Config.debugLogging {
                let params = body["params"] as? [String: Any]
                let level = (params?["level"] as? String) ?? "log"
                let message = (params?["message"] as? String) ?? ""
                print("🧭 [Web \(level)] \(message)")
            }
            respond(requestId: requestId, result: ["logged": true])
        case "getCachedVideoURL":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            let cachedURL = MorphVideoCacheManager.shared.displayURL(for: urlString, mediaType: "video")
            respond(requestId: requestId, result: [
                "url": cachedURL?.absoluteString ?? NSNull(),
                "cached": cachedURL != nil
            ])
        case "prefetchVideo":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            Task {
                _ = await MorphVideoCacheManager.shared.prefetch(remoteURLString: urlString, mediaType: "video")
                let cachedURL = MorphVideoCacheManager.shared.displayURL(for: urlString, mediaType: "video")
                await MainActor.run {
                    self.respond(requestId: requestId, result: [
                        "url": cachedURL?.absoluteString ?? NSNull(),
                        "cached": cachedURL != nil
                    ])
                }
            }
        #endif
        case "getCachedMediaURL":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            let mediaType = Self.stringParam("mediaType", from: body)
            let cachedURL = MorphVideoCacheManager.shared.displayURL(for: urlString, mediaType: mediaType)
            respond(requestId: requestId, result: [
                "url": cachedURL?.absoluteString ?? NSNull(),
                "cached": cachedURL != nil
            ])
        case "prefetchMedia":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            let mediaType = Self.stringParam("mediaType", from: body)
            Task {
                _ = await MorphVideoCacheManager.shared.prefetch(remoteURLString: urlString, mediaType: mediaType)
                let cachedURL = MorphVideoCacheManager.shared.displayURL(for: urlString, mediaType: mediaType)
                await MainActor.run {
                    self.respond(requestId: requestId, result: [
                        "url": cachedURL?.absoluteString ?? NSNull(),
                        "cached": cachedURL != nil
                    ])
                }
            }
        case "saveMediaToAlbum":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            let mediaType = Self.stringParam("mediaType", from: body)
            let fileName = Self.stringParam("fileName", from: body)
            Task {
                do {
                    let result = try await Self.saveMediaToAlbum(urlString: urlString, mediaType: mediaType, fileName: fileName)
                    await MainActor.run {
                        self.respond(requestId: requestId, result: result)
                    }
                } catch {
                    let nsError = error as NSError
                    let code = nsError.domain == "AppAlbum" && nsError.code == -2
                        ? "PHOTO_LIBRARY_PERMISSION_DENIED"
                        : "SAVE_ALBUM_FAILED"
                    await MainActor.run {
                        self.respond(requestId: requestId, error: [
                            "code": code,
                            "message": error.localizedDescription
                        ])
                    }
                }
            }
        #if DEBUG
        case "getTemplateFeedCache":
            debugLog("call \(typeName)")
            let key = Self.stringParam("key", from: body)
            respond(requestId: requestId, result: MorphJSONCacheManager.shared.value(namespace: "templateFeed", key: key))
        case "setTemplateFeedCache":
            debugLog("call \(typeName)")
            let params = Self.params(from: body)
            let key = params["key"] as? String ?? ""
            let value = params["value"] ?? NSNull()
            let ttl = params["ttlSeconds"] as? TimeInterval
            let saved = MorphJSONCacheManager.shared.setValue(namespace: "templateFeed", key: key, value: value, ttlSeconds: ttl)
            respond(requestId: requestId, result: ["saved": saved])
        case "getTemplateDetailCache":
            debugLog("call \(typeName)")
            let key = Self.stringParam("key", from: body)
            respond(requestId: requestId, result: MorphJSONCacheManager.shared.value(namespace: "templateDetail", key: key))
        case "setTemplateDetailCache":
            debugLog("call \(typeName)")
            let params = Self.params(from: body)
            let key = params["key"] as? String ?? ""
            let value = params["value"] ?? NSNull()
            let ttl = params["ttlSeconds"] as? TimeInterval
            let saved = MorphJSONCacheManager.shared.setValue(namespace: "templateDetail", key: key, value: value, ttlSeconds: ttl)
            respond(requestId: requestId, result: ["saved": saved])
        #endif
        case "getJSONCache":
            debugLog("call \(typeName)")
            let params = Self.params(from: body)
            let namespace = params["namespace"] as? String ?? "default"
            let key = params["key"] as? String ?? ""
            respond(requestId: requestId, result: MorphJSONCacheManager.shared.value(namespace: namespace, key: key))
        case "setJSONCache":
            debugLog("call \(typeName)")
            let params = Self.params(from: body)
            let namespace = params["namespace"] as? String ?? "default"
            let key = params["key"] as? String ?? ""
            let value = params["value"] ?? NSNull()
            let ttl = params["ttlSeconds"] as? TimeInterval
            let saved = MorphJSONCacheManager.shared.setValue(namespace: namespace, key: key, value: value, ttlSeconds: ttl)
            respond(requestId: requestId, result: ["saved": saved])
        case "pickPhoto":
            debugLog("call \(typeName)")
            guard AIDataConsentManager.hasGranted else {
                respond(requestId: requestId, error: [
                    "code": "AI_CONSENT_REQUIRED",
                    "message": "User consent is required before sharing photos with AI services."
                ])
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .morphAIDataConsentRequired, object: nil)
                }
                return
            }
            guard pendingPhotoRequestId == nil else {
                respond(requestId: requestId, error: [
                    "code": "PHOTO_PICKER_BUSY",
                    "message": "Photo picker is already presented"
                ])
                return
            }
            pendingPhotoRequestId = requestId
            presentPhotoPicker()
        case "registerPush":
            debugLog("call \(typeName)")
            MorphPushManager.shared.register { [weak self] result in
                DispatchQueue.main.async {
                    self?.respond(requestId: requestId, result: result)
                }
            }
        case "getLaunchPushPayload":
            debugLog("call \(typeName)")
            respond(requestId: requestId, result: MorphPushManager.shared.consumeLaunchPayload())
        case "openPayment":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            let type = Self.stringParam("type", from: body)
            if type == "apple_pay" && urlString.isEmpty {
                let params = Self.params(from: body)
                Task {
                    let result = await MorphH5PaymentManager.shared.purchase(params: params)
                    await MainActor.run {
                        self.respond(requestId: requestId, result: result)
                    }
                }
                return
            }
            guard let url = URL(string: urlString) else {
                respond(requestId: requestId, error: [
                    "code": "INVALID_URL",
                    "message": "Payment URL is invalid"
                ])
                return
            }
            let opened = presentPaymentBrowser(url: url, params: Self.params(from: body), requestId: requestId)
            if !opened {
                respond(requestId: requestId, result: ["opened": false, "status": "failed"])
            }
        case "restorePayment":
            debugLog("call \(typeName)")
            Task {
                let result = await MorphH5PaymentManager.shared.restoreTransactions()
                await MainActor.run {
                    self.respond(requestId: requestId, result: result)
                }
            }
        case "finishPaymentTransaction":
            debugLog("call \(typeName)")
            let transactionId = Self.stringParam("transactionId", from: body)
            Task {
                let result = await MorphH5PaymentManager.shared.finishTransaction(transactionId: transactionId)
                await MainActor.run {
                    self.respond(requestId: requestId, result: result)
                }
            }
        case "openURL":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
                respond(requestId: requestId, result: ["opened": false])
                return
            }
            UIApplication.shared.open(url) { [weak self] opened in
                self?.respond(requestId: requestId, result: ["opened": opened])
            }
        case "openWebView":
            debugLog("call \(typeName)")
            let urlString = Self.stringParam("url", from: body)
            let title = Self.stringParam("title", from: body)
            guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                respond(requestId: requestId, result: ["opened": false])
                return
            }
            let opened = presentBrowserWebView(url: url, title: title)
            respond(requestId: requestId, result: ["opened": opened])
        case "openSettings":
            debugLog("call \(typeName)")
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                respond(requestId: requestId, result: ["opened": false])
                return
            }
            UIApplication.shared.open(url) { [weak self] opened in
                self?.respond(requestId: requestId, result: ["opened": opened])
            }
        case "showToast":
            debugLog("call \(typeName)")
            let message = Self.stringParam("message", from: body)
            showToast(message: message)
            respond(requestId: requestId, result: ["shown": !message.isEmpty])
        case "back":
            debugLog("call \(typeName)")
            if viewModel?.webView.canGoBack == true {
                viewModel?.webView.goBack()
                respond(requestId: requestId, result: ["handled": true])
            } else {
                respond(requestId: requestId, result: ["handled": false])
            }
        default:
            debugLog("unhandled \(typeName)")
            respond(requestId: requestId, error: [
                "code": "METHOD_NOT_IMPLEMENTED",
                "message": "Native action is not implemented: \(typeName)"
            ])
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        viewModel?.navigationFinished()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        viewModel?.fail(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        viewModel?.fail(error.localizedDescription)
    }

    private func respond(requestId: String, result: [String: Any]) {
        send(requestId: requestId, payload: ["ok": true, "result": result])
    }

    private func respond(requestId: String, error: [String: Any]) {
        send(requestId: requestId, payload: ["ok": false, "error": error])
    }

    private func send(requestId: String, payload: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else { return }

        let script = "window.__syncAppInfoResolve && window.__syncAppInfoResolve('\(requestId)', \(json));"
        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.webView.evaluateJavaScript(script)
        }
    }

    private func dispatchNativeEvent(name: String, payload: [String: Any]) {
        let detail: [String: Any] = ["name": name, "payload": payload]
        guard
            let data = try? JSONSerialization.data(withJSONObject: detail),
            let json = String(data: data, encoding: .utf8)
        else { return }

        let script = "window.dispatchEvent(new CustomEvent('morph:native-event', { detail: \(json) }));"
        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.webView.evaluateJavaScript(script)
        }
    }

    @objc private func handlePushPayloadNotification(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? [String: Any] else { return }
        let source = notification.userInfo?["source"] as? String ?? "unknown"
        debugLog("push payload from \(source)")
        presentForegroundPushToastIfNeeded(payload: payload, source: source)
    }

    private func presentForegroundPushToastIfNeeded(payload: [String: Any], source: String) {
        guard source.contains("foreground") || source.contains("willPresent") else { return }
        let message = (payload["title"] as? String)
            ?? (payload["body"] as? String)
            ?? (payload["alert"] as? String)
        guard let message, !message.isEmpty else { return }
        showToast(message: message)
    }

    @objc private func handlePaymentCallbackNotification(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? [String: Any] else { return }
        let hasActiveRequest = activePaymentRequestId != nil
        if let requestId = activePaymentRequestId {
            activePaymentRequestId = nil
            respond(requestId: requestId, result: payload)
        }
        activePaymentBrowserContext = nil
        dismissActivePaymentBrowser()
        if !hasActiveRequest {
            dispatchNativeEvent(name: "payment.callback", payload: payload)
        }
    }

    @objc private func handlePaymentTransactionNotification(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? [String: Any] else { return }
        dispatchNativeEvent(name: "payment.transaction", payload: payload)
    }

    private func showToast(message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        DispatchQueue.main.async {
            guard let container = Self.topViewController()?.view else { return }
            container.viewWithTag(Self.toastViewTag)?.removeFromSuperview()

            let toast = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            toast.tag = Self.toastViewTag
            toast.alpha = 0
            toast.layer.cornerRadius = 18
            toast.layer.cornerCurve = .continuous
            toast.layer.borderWidth = 1
            toast.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            toast.clipsToBounds = true

            let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            icon.tintColor = UIColor(red: 0.88, green: 0.22, blue: 0.62, alpha: 1)
            icon.contentMode = .scaleAspectFit
            icon.setContentHuggingPriority(.required, for: .horizontal)

            let label = UILabel()
            label.text = trimmedMessage
            label.textColor = UIColor.white.withAlphaComponent(0.92)
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.numberOfLines = 2
            label.textAlignment = .center

            let stack = UIStackView(arrangedSubviews: [icon, label])
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 8

            container.addSubview(toast)
            toast.contentView.addSubview(stack)
            toast.translatesAutoresizingMaskIntoConstraints = false
            stack.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 18),
                icon.heightAnchor.constraint(equalToConstant: 18),
                toast.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                toast.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                toast.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -64),
                toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 42),
                stack.leadingAnchor.constraint(equalTo: toast.contentView.leadingAnchor, constant: 18),
                stack.trailingAnchor.constraint(equalTo: toast.contentView.trailingAnchor, constant: -18),
                stack.topAnchor.constraint(equalTo: toast.contentView.topAnchor, constant: 12),
                stack.bottomAnchor.constraint(equalTo: toast.contentView.bottomAnchor, constant: -12)
            ])

            toast.transform = CGAffineTransform(scaleX: 0.96, y: 0.96).translatedBy(x: 0, y: 8)
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                toast.alpha = 1
                toast.transform = .identity
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
                    toast.alpha = 0
                    toast.transform = CGAffineTransform(scaleX: 0.98, y: 0.98).translatedBy(x: 0, y: -4)
                } completion: { _ in
                    toast.removeFromSuperview()
                }
            }
        }
    }

    private func presentPaymentBrowser(url: URL, params: [String: Any], requestId: String) -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        if let activePaymentBrowser {
            if let activePaymentRequestId {
                respond(requestId: activePaymentRequestId, result: [
                    "opened": false,
                    "status": "cancelled",
                    "result": "cancelled",
                    "message": "Payment page was replaced."
                ])
            }
            activePaymentRequestId = nil
            activePaymentBrowser.dismiss(animated: false)
        }

        activePaymentRequestId = requestId
        activePaymentBrowserContext = paymentBrowserContext(from: params, url: url)
        let browser = MorphAppPaymentController(url: url) { [weak self] in
            self?.handlePaymentBrowserClosed()
        }
        browser.modalPresentationStyle = .fullScreen
        activePaymentBrowser = browser
        presenter.present(browser, animated: true)
        return true
    }

    private func presentBrowserWebView(url: URL, title: String) -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        let browser = MorphAppPageController(url: url, title: title.isEmpty ? MorphH5Config.appDisplayName : title)
        browser.modalPresentationStyle = .fullScreen
        presenter.present(browser, animated: true)
        return true
    }

    private func paymentBrowserContext(from params: [String: Any], url: URL) -> [String: Any] {
        var context: [String: Any] = [
            "url": url.absoluteString,
            "status": "cancelled",
            "message": "Payment page was closed."
        ]
        for key in ["orderId", "order_id", "payChannelId", "pay_channel_id", "packageId", "package_id", "type"] {
            if let value = params[key] {
                context[key] = value
            }
        }
        if context["order_id"] == nil, let orderId = context["orderId"] {
            context["order_id"] = orderId
        }
        if context["pay_channel_id"] == nil, let payChannelId = context["payChannelId"] {
            context["pay_channel_id"] = payChannelId
        }
        return context
    }

    private func dismissActivePaymentBrowser() {
        guard let browser = activePaymentBrowser else { return }
        activePaymentBrowser = nil
        browser.dismiss(animated: true)
    }

    private func handlePaymentBrowserClosed() {
        activePaymentBrowser = nil

        var payload = activePaymentBrowserContext ?? [:]
        payload["status"] = payload["status"] ?? "cancelled"
        payload["result"] = payload["result"] ?? "cancelled"
        activePaymentBrowserContext = nil
        if let requestId = activePaymentRequestId {
            activePaymentRequestId = nil
            respond(requestId: requestId, result: payload)
        }
    }

    private static func stringParam(_ key: String, from body: [String: Any]) -> String {
        params(from: body)[key] as? String ?? ""
    }

    private static func eventNameParam(from params: [String: Any]) -> String {
        let candidates = ["eventName", "name", "event"]
        for key in candidates {
            if let value = params[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    private static func eventValuesParam(from params: [String: Any]) -> [String: Any]? {
        let candidates = ["values", "eventValues", "params", "properties"]
        for key in candidates {
            if let value = params[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private func debugLog(_ message: String) {
        guard MorphH5Config.debugLogging else { return }
        print("🔗 [Bridge] \(message)")
    }

    private static func params(from body: [String: Any]) -> [String: Any] {
        body["params"] as? [String: Any] ?? [:]
    }

    private static func saveMediaToAlbum(urlString: String, mediaType: String, fileName: String) async throws -> [String: Any] {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            throw NSError(domain: "MorphAlbum", code: -1, userInfo: [NSLocalizedDescriptionKey: "Media URL is invalid"])
        }

        let authorized = await requestPhotoAddPermission()
        guard authorized else {
            throw NSError(domain: "MorphAlbum", code: -2, userInfo: [NSLocalizedDescriptionKey: "Photo library permission denied"])
        }

        let resolvedType = resolveMediaType(mediaType: mediaType, url: url, fileName: fileName)
        if resolvedType == "video" {
            let (localURL, shouldCleanupLocalURL) = try await localMediaURL(
                for: url,
                originalURLString: urlString,
                mediaType: resolvedType,
                fileName: fileName.isEmpty ? "creation.mp4" : fileName
            )
            defer {
                if shouldCleanupLocalURL {
                    try? FileManager.default.removeItem(at: localURL)
                }
            }
            var requested = false
            try await PHPhotoLibrary.shared().performChanges {
                requested = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localURL) != nil
            }
            guard requested else {
                throw NSError(domain: "MorphAlbum", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to save video"])
            }
            return ["saved": true, "mediaType": "video"]
        }

        let data = try await mediaData(from: url, originalURLString: urlString, mediaType: resolvedType)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "MorphAlbum", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unable to read image"])
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        return ["saved": true, "mediaType": "image"]
    }

    private static func requestPhotoAddPermission() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current == .authorized || current == .limited { return true }
        if current == .denied || current == .restricted { return false }
        let next = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return next == .authorized || next == .limited
    }

    private static func resolveMediaType(mediaType: String, url: URL, fileName: String) -> String {
        let raw = mediaType.lowercased()
        if raw == "video" || raw == "image" { return raw }
        let path = (fileName.isEmpty ? url.path : fileName).lowercased()
        if path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".m4v") { return "video" }
        return "image"
    }

    private static func mediaData(from url: URL, originalURLString: String, mediaType: String) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cachedURL = cachedMediaURLForAlbum(url: url, originalURLString: originalURLString, mediaType: mediaType) {
            return try Data(contentsOf: cachedURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NSError(
                domain: "MorphAlbum",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Media download failed"]
            )
        }
        return data
    }

    private static func localMediaURL(for url: URL, originalURLString: String, mediaType: String, fileName: String) async throws -> (url: URL, shouldCleanup: Bool) {
        if url.isFileURL { return (url, false) }
        if let cachedURL = cachedMediaURLForAlbum(url: url, originalURLString: originalURLString, mediaType: mediaType) {
            return (cachedURL, false)
        }
        let remoteURLString = cacheSourceURLString(from: url, fallback: originalURLString)
        if !remoteURLString.isEmpty,
           let prefetchedURL = await MorphVideoCacheManager.shared.prefetch(remoteURLString: remoteURLString, mediaType: mediaType) {
            return (prefetchedURL, false)
        }
        return try await downloadMediaToTemporaryFile(from: url, fileName: fileName)
    }

    private static func downloadMediaToTemporaryFile(from url: URL, fileName: String) async throws -> (url: URL, shouldCleanup: Bool) {
        let (downloadedURL, response) = try await URLSession.shared.download(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            try? FileManager.default.removeItem(at: downloadedURL)
            throw NSError(
                domain: "MorphAlbum",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Media download failed"]
            )
        }
        let safeName = fileName.replacingOccurrences(of: "/", with: "_")
        let fallbackExtension = (safeName as NSString).pathExtension.isEmpty ? (url.pathExtension.isEmpty ? "mp4" : url.pathExtension) : (safeName as NSString).pathExtension
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fallbackExtension)
        try FileManager.default.moveItem(at: downloadedURL, to: localURL)
        return (localURL, true)
    }

    private static func cachedMediaURLForAlbum(url: URL, originalURLString: String, mediaType: String) -> URL? {
        let remoteURLString = cacheSourceURLString(from: url, fallback: originalURLString)
        guard !remoteURLString.isEmpty else { return nil }
        return MorphVideoCacheManager.shared.cachedURL(for: remoteURLString, mediaType: mediaType)
    }

    private static func cacheSourceURLString(from url: URL, fallback: String) -> String {
        if url.scheme == MorphMediaCacheSchemeHandler.scheme,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let remote = components.queryItems?.first(where: { $0.name == "url" })?.value,
           !remote.isEmpty {
            return remote
        }
        return fallback
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        guard let presenter = Self.topViewController() else {
            if let requestId = pendingPhotoRequestId {
                respond(requestId: requestId, error: [
                    "code": "PRESENTER_UNAVAILABLE",
                    "message": "Unable to present photo picker"
                ])
            }
            pendingPhotoRequestId = nil
            return
        }

        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let requestId = pendingPhotoRequestId else { return }
        pendingPhotoRequestId = nil

        guard let provider = results.first?.itemProvider else {
            respond(requestId: requestId, error: [
                "code": "PHOTO_CANCELLED",
                "message": "Photo selection was cancelled"
            ])
            return
        }

        guard provider.canLoadObject(ofClass: UIImage.self) else {
            respond(requestId: requestId, error: [
                "code": "PHOTO_UNSUPPORTED",
                "message": "Selected item is not a supported image"
            ])
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error {
                DispatchQueue.main.async {
                    self?.respond(requestId: requestId, error: [
                        "code": "PHOTO_LOAD_FAILED",
                        "message": error.localizedDescription
                    ])
                }
                return
            }

            guard let image = object as? UIImage,
                  let encodedPhoto = Self.encodePhotoForBridge(image) else {
                DispatchQueue.main.async {
                    self?.respond(requestId: requestId, error: [
                        "code": "PHOTO_ENCODE_FAILED",
                        "message": "Unable to encode selected photo"
                    ])
                }
                return
            }

            let base64 = encodedPhoto.data.base64EncodedString()
            let validation = Self.validatePhotoForBridge(image)
            DispatchQueue.main.async {
                self?.respond(requestId: requestId, result: [
                    "dataURL": "data:image/jpeg;base64,\(base64)",
                    "fileName": "photo.jpg",
                    "mimeType": "image/jpeg",
                    "width": encodedPhoto.width,
                    "height": encodedPhoto.height,
                    "fileSize": encodedPhoto.data.count,
                    "validation": validation
                ])
            }
        }
    }

    private static func validatePhotoForBridge(_ image: UIImage) -> [String: Any] {
        guard let cgImage = image.cgImage else {
            return [
                "isValid": false,
                "faceCount": 0,
                "reasons": ["no_person"]
            ]
        }

        let orientation = cgImageOrientation(from: image.imageOrientation)
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision2
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
            let observations = request.results ?? []
            if observations.isEmpty {
                return validatePhotoWithFaceRectangles(cgImage: cgImage, orientation: orientation)
            }
            return validationResult(from: observations)
        } catch {
            let nsError = error as NSError
            if nsError.code == 9 {
                return [
                    "isValid": true,
                    "skipped": true,
                    "faceCount": 0,
                    "reasons": []
                ]
            }
            return validatePhotoWithFaceRectangles(cgImage: cgImage, orientation: orientation)
        }
    }

    private static func validatePhotoWithFaceRectangles(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [String: Any] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            guard !observations.isEmpty else {
                return [
                    "isValid": false,
                    "faceCount": 0,
                    "reasons": ["no_person"]
                ]
            }
            return validationResult(from: observations)
        } catch {
            let nsError = error as NSError
            if nsError.code == 9 {
                return [
                    "isValid": true,
                    "skipped": true,
                    "faceCount": 0,
                    "reasons": []
                ]
            }
            return [
                "isValid": false,
                "faceCount": 0,
                "reasons": ["no_person"]
            ]
        }
    }

    private static func validationResult(from observations: [VNFaceObservation]) -> [String: Any] {
        if observations.count > 1 {
            return [
                "isValid": false,
                "faceCount": observations.count,
                "reasons": ["multiple_people"]
            ]
        }

        guard let face = observations.first else {
            return [
                "isValid": false,
                "faceCount": 0,
                "reasons": ["no_person"]
            ]
        }

        var reasons: [String] = []
        let box = face.boundingBox
        if face.confidence < 0.3 || box.width < 0.05 || box.height < 0.05 {
            reasons.append("face_offset_or_obscured")
        } else if let roll = face.roll {
            let rollAngleDegrees = abs(roll.doubleValue) * 180 / .pi
            if rollAngleDegrees > 90 {
                reasons.append("face_offset_or_obscured")
            }
        } else if face.confidence < 0.4 {
            reasons.append("face_offset_or_obscured")
        }

        return [
            "isValid": reasons.isEmpty,
            "faceCount": 1,
            "reasons": reasons
        ]
    }

    private static func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func encodePhotoForBridge(_ image: UIImage) -> (data: Data, width: Int, height: Int)? {
        let maxPixel: CGFloat = 2048
        let maxBytes = 12 * 1024 * 1024
        let sourceWidth = image.size.width * image.scale
        let sourceHeight = image.size.height * image.scale
        let longestSide = max(sourceWidth, sourceHeight)
        let resizeScale = longestSide > maxPixel ? maxPixel / longestSide : 1
        let outputWidth = max(1, Int(sourceWidth * resizeScale))
        let outputHeight = max(1, Int(sourceHeight * resizeScale))
        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let outputImage: UIImage

        if resizeScale < 1 {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            outputImage = UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: outputSize))
            }
        } else {
            outputImage = image
        }

        let qualities: [CGFloat] = [0.9, 0.82, 0.74, 0.66, 0.58, 0.5]
        for quality in qualities {
            guard let data = outputImage.jpegData(compressionQuality: quality) else { continue }
            if data.count <= maxBytes || quality == qualities.last {
                return (data, outputWidth, outputHeight)
            }
        }
        return nil
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
