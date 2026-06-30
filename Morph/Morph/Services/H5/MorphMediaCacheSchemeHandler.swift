//
//  MorphMediaCacheSchemeHandler.swift
//  App
//

import Foundation
import WebKit

final class MorphMediaCacheSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "app-media"
    private let ioQueue = DispatchQueue(label: "app.media-cache.scheme-handler", qos: .userInitiated, attributes: .concurrent)
    private let stateLock = NSLock()
    private var stoppedTaskIDs = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        stateLock.lock()
        stoppedTaskIDs.remove(taskID)
        stateLock.unlock()
        ioQueue.async { [weak self] in
            self?.serve(urlSchemeTask, taskID: taskID)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask as AnyObject)
        stateLock.lock()
        stoppedTaskIDs.insert(taskID)
        stateLock.unlock()
    }

    private func serve(_ urlSchemeTask: WKURLSchemeTask, taskID: ObjectIdentifier) {
        defer { clearStopped(taskID) }
        guard let requestURL = urlSchemeTask.request.url,
              let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              let remoteURLString = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let mediaType = components.queryItems?.first(where: { $0.name == "type" })?.value,
              let fileURL = MorphVideoCacheManager.shared.cachedURL(for: remoteURLString, mediaType: mediaType),
              let totalLength = fileLength(for: fileURL),
              totalLength > 0 else {
            fail(urlSchemeTask, url: urlSchemeTask.request.url, taskID: taskID)
            return
        }

        guard !isStopped(taskID) else { return }
        let range = byteRange(from: urlSchemeTask.request, totalLength: totalLength)
        let headers = responseHeaders(for: fileURL, range: range, totalLength: totalLength, mediaType: mediaType)
        let statusCode = range.count == totalLength ? 200 : 206
        let response = HTTPURLResponse(url: requestURL, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
        urlSchemeTask.didReceive(response)
        stream(fileURL: fileURL, range: range, to: urlSchemeTask, taskID: taskID)
    }

    private func stream(fileURL: URL, range: Range<Int>, to urlSchemeTask: WKURLSchemeTask, taskID: ObjectIdentifier) {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(range.lowerBound))
            var remaining = range.count
            let chunkSize = 256 * 1024
            while remaining > 0 {
                if isStopped(taskID) { return }
                let data = autoreleasepool(invoking: {
                    handle.readData(ofLength: min(chunkSize, remaining))
                })
                if data.isEmpty { break }
                remaining -= data.count
                urlSchemeTask.didReceive(data)
            }
            if !isStopped(taskID) {
                urlSchemeTask.didFinish()
            }
        } catch {
            if !isStopped(taskID) {
                urlSchemeTask.didFailWithError(error)
            }
        }
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

    private func fail(_ task: WKURLSchemeTask, url: URL?, taskID: ObjectIdentifier) {
        guard !isStopped(taskID) else { return }
        let responseURL = url ?? URL(string: "\(Self.scheme)://missing")!
        let response = HTTPURLResponse(url: responseURL, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
        task.didReceive(response)
        task.didFinish()
    }

    private func isStopped(_ taskID: ObjectIdentifier) -> Bool {
        stateLock.lock()
        let stopped = stoppedTaskIDs.contains(taskID)
        stateLock.unlock()
        return stopped
    }

    private func clearStopped(_ taskID: ObjectIdentifier) {
        stateLock.lock()
        stoppedTaskIDs.remove(taskID)
        stateLock.unlock()
    }
}
