//
//  MorphVideoCacheManager.swift
//  App
//

import Foundation
import CryptoKit

final class MorphVideoCacheManager {
    static let shared = MorphVideoCacheManager()

    private let session: URLSession
    private let videoDirectory: URL
    private let imageDirectory: URL
    private let stateLock = NSLock()
    private var inFlightDownloads: [String: Task<URL?, Never>] = [:]
    private let maxFilesPerMediaType = 180

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        videoDirectory = caches.appendingPathComponent("AppVideoCache", isDirectory: true)
        imageDirectory = caches.appendingPathComponent("AppImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
    }

    func cachedURL(for remoteURLString: String, mediaType: String? = nil) -> URL? {
        guard !remoteURLString.isEmpty else { return nil }
        let fileURL = localURL(for: remoteURLString, mediaType: mediaType)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        debugLog("\(exists ? "hit" : "miss") \(mediaType ?? "video") url=\(remoteURLString)")
        return exists ? fileURL : nil
    }

    func displayURL(for remoteURLString: String, mediaType: String? = nil) -> URL? {
        guard cachedURL(for: remoteURLString, mediaType: mediaType) != nil else { return nil }
        var components = URLComponents()
        components.scheme = MorphMediaCacheSchemeHandler.scheme
        components.host = mediaType == "image" ? "image" : "video"
        components.path = "/media"
        components.queryItems = [
            URLQueryItem(name: "type", value: mediaType == "image" ? "image" : "video"),
            URLQueryItem(name: "url", value: remoteURLString)
        ]
        return components.url
    }

    func prefetch(remoteURLString: String, mediaType: String? = nil) async -> URL? {
        if let cachedURL = cachedURL(for: remoteURLString, mediaType: mediaType) {
            return cachedURL
        }

        let key = cacheKey(for: remoteURLString, mediaType: mediaType)
        if let existingTask = downloadTask(for: key) {
            debugLog("dedupe \(mediaType ?? "video") url=\(remoteURLString)")
            return await existingTask.value
        }

        let task = Task<URL?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.download(remoteURLString: remoteURLString, mediaType: mediaType)
        }
        setDownloadTask(task, for: key)

        let result = await task.value
        removeDownloadTask(for: key)
        return result
    }

    private func download(remoteURLString: String, mediaType: String?) async -> URL? {
        guard let remoteURL = URL(string: remoteURLString) else { return nil }

        do {
            let (tempURL, response) = try await session.download(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let destination = localURL(for: remoteURLString, mediaType: mediaType)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tempURL, to: destination)
            trim(directory: directory(for: mediaType))
            debugLog("downloaded \(mediaType ?? "video") url=\(remoteURLString)")
            return destination
        } catch {
            print("⚠️ [VideoCache] prefetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func localURL(for remoteURLString: String, mediaType: String?) -> URL {
        let ext = fileExtension(for: remoteURLString, mediaType: mediaType)
        let name = "\(stableCacheFileName(for: remoteURLString, mediaType: mediaType)).\(ext)"
        return directory(for: mediaType).appendingPathComponent(name)
    }

    private func cacheKey(for remoteURLString: String, mediaType: String?) -> String {
        "\(mediaType ?? "video")::\(remoteURLString)"
    }

    private func stableCacheFileName(for remoteURLString: String, mediaType: String?) -> String {
        let raw = "\(mediaType ?? "video")::\(remoteURLString)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func downloadTask(for key: String) -> Task<URL?, Never>? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return inFlightDownloads[key]
    }

    private func setDownloadTask(_ task: Task<URL?, Never>, for key: String) {
        stateLock.lock()
        inFlightDownloads[key] = task
        stateLock.unlock()
    }

    private func removeDownloadTask(for key: String) {
        stateLock.lock()
        inFlightDownloads.removeValue(forKey: key)
        stateLock.unlock()
    }

    private func directory(for mediaType: String?) -> URL {
        mediaType == "image" ? imageDirectory : videoDirectory
    }

    private func fileExtension(for remoteURLString: String, mediaType: String?) -> String {
        if let ext = URL(string: remoteURLString)?.pathExtension, !ext.isEmpty {
            return ext
        }
        return mediaType == "image" ? "jpg" : "mp4"
    }

    private func trim(directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ), files.count > maxFilesPerMediaType else {
            return
        }

        let sorted = files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }

        for file in sorted.prefix(files.count - maxFilesPerMediaType) {
            try? FileManager.default.removeItem(at: file)
        }
        debugLog("trimmed \(files.count - maxFilesPerMediaType) files in \(directory.lastPathComponent)")
    }

    private func debugLog(_ message: String) {
        guard MorphH5Config.debugLogging else { return }
        print("🎞️ [MediaCache] \(message)")
    }
}
