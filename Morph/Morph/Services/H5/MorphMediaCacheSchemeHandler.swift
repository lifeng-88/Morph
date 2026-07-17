//
//  MorphMediaCacheSchemeHandler.swift
//  App
//

import Foundation
import WebKit

/// 每个 WKURLSchemeTask 的会话状态。所有对 WK 的回调都在 `callbackQueue` 串行执行。
private final class SchemeTaskSession {
    let task: WKURLSchemeTask
    private var stopped = false
    private var finished = false

    init(task: WKURLSchemeTask) {
        self.task = task
    }

    func markStopped() {
        stopped = true
    }

    var isActive: Bool { !stopped && !finished }

    @discardableResult
    func receive(response: URLResponse) -> Bool {
        guard isActive else { return false }
        guard MorphWKSchemeTaskSafe.receiveResponse(task, response: response) else {
            stopped = true
            return false
        }
        return true
    }

    @discardableResult
    func receive(data: Data) -> Bool {
        guard isActive else { return false }
        guard MorphWKSchemeTaskSafe.receiveData(task, data: data) else {
            stopped = true
            return false
        }
        return true
    }

    @discardableResult
    func finish() -> Bool {
        guard isActive else { return false }
        finished = true
        guard MorphWKSchemeTaskSafe.finish(task) else {
            stopped = true
            return false
        }
        return true
    }

    @discardableResult
    func fail(_ error: Error) -> Bool {
        guard isActive else { return false }
        finished = true
        guard MorphWKSchemeTaskSafe.fail(task, error: error as NSError) else {
            stopped = true
            return false
        }
        return true
    }
}

final class MorphMediaCacheSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "app-media"

    /// 唯一串行队列：stop / didReceive / didFinish 全部走这里，禁止跨线程回调 WK。
    private let callbackQueue = DispatchQueue(label: "app.media-cache.scheme-callback")
    private let ioQueue = DispatchQueue(label: "app.media-cache.scheme-io", qos: .userInitiated)
    private var sessions: [ObjectIdentifier: SchemeTaskSession] = [:]

    override init() {
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        let session = SchemeTaskSession(task: urlSchemeTask)

        callbackQueue.async { [weak self] in
            self?.sessions[taskID] = session
        }

        ioQueue.async { [weak self] in
            self?.serve(session: session, taskID: taskID)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        callbackQueue.async { [weak self] in
            self?.sessions[taskID]?.markStopped()
        }
    }

    private func serve(session: SchemeTaskSession, taskID: ObjectIdentifier) {
        defer {
            callbackQueue.async { [weak self] in
                self?.sessions.removeValue(forKey: taskID)
            }
        }

        guard let requestURL = session.task.request.url,
              let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let remoteURLString = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let mediaType = components.queryItems?.first(where: { $0.name == "type" })?.value,
              let fileURL = MorphVideoCacheManager.shared.cachedURL(for: remoteURLString, mediaType: mediaType),
              let totalLength = fileLength(for: fileURL),
              totalLength > 0 else {
            deliver404(session: session)
            return
        }

        let range = byteRange(from: session.task.request, totalLength: totalLength)
        let headers = responseHeaders(for: fileURL, range: range, totalLength: totalLength, mediaType: mediaType)
        let statusCode = range.count == totalLength ? 200 : 206
        let response = HTTPURLResponse(
            url: requestURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!

        let accepted = deliver { session.receive(response: response) }
        guard accepted else { return }
        stream(fileURL: fileURL, range: range, session: session)
    }

    private func stream(fileURL: URL, range: Range<Int>, session: SchemeTaskSession) {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(range.lowerBound))

            var remaining = range.count
            let chunkSize = 64 * 1024
            while remaining > 0 {
                let data = autoreleasepool(invoking: {
                    handle.readData(ofLength: min(chunkSize, remaining))
                })
                if data.isEmpty { break }
                remaining -= data.count
                // 拷贝一份再投递，避免 FileHandle buffer 生命周期问题
                let chunk = Data(data)
                let ok = deliver { session.receive(data: chunk) }
                if !ok { return }
            }
            _ = deliver { session.finish() }
        } catch {
            _ = deliver { session.fail(error) }
        }
    }

    private func deliver404(session: SchemeTaskSession) {
        let responseURL = session.task.request.url ?? URL(string: "\(Self.scheme)://missing")!
        let response = HTTPURLResponse(
            url: responseURL,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        _ = deliver {
            guard session.receive(response: response) else { return false }
            return session.finish()
        }
    }

    /// 在 callbackQueue 上同步执行一次投递；调用方在 ioQueue，不会造成主线程死锁。
    @discardableResult
    private func deliver(_ block: @escaping () -> Bool) -> Bool {
        callbackQueue.sync(execute: block)
    }

    private func byteRange(from request: URLRequest, totalLength: Int) -> Range<Int> {
        guard totalLength > 0,
              let header = request.value(forHTTPHeaderField: "Range"),
              header.hasPrefix("bytes=") else {
            return 0..<totalLength
        }

        let rawRange = header.dropFirst("bytes=".count)
        let parts = rawRange.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return 0..<totalLength }

        let start = Int(parts[0]) ?? 0
        let end = parts[1].isEmpty ? totalLength - 1 : (Int(parts[1]) ?? totalLength - 1)
        let lower = max(0, min(start, totalLength - 1))
        let upper = max(lower, min(end, totalLength - 1))
        return lower..<(upper + 1)
    }

    private func fileLength(for fileURL: URL) -> Int? {
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else {
            return nil
        }
        return size
    }

    private func responseHeaders(for fileURL: URL, range: Range<Int>, totalLength: Int, mediaType: String) -> [String: String] {
        var headers = [
            "Content-Type": mimeType(for: fileURL, mediaType: mediaType),
            "Content-Length": String(range.count),
            "Accept-Ranges": "bytes",
            "Cache-Control": "public, max-age=31536000"
        ]
        if range.count != totalLength {
            headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(totalLength)"
        }
        return headers
    }

    private func mimeType(for fileURL: URL, mediaType: String) -> String {
        if mediaType == "image" { return "image/jpeg" }
        switch fileURL.pathExtension.lowercased() {
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        case "webm":
            return "video/webm"
        default:
            return "video/mp4"
        }
    }
}
