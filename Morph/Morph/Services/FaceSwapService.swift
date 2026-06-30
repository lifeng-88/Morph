import UIKit

struct FaceSwapRequest {
    let sourceImage: UIImage
    let templateId: String
    let templateImage: UIImage
    let hdQuality: Bool
    let faceEnhancement: Bool
}

enum FaceSwapError: LocalizedError {
    case invalidResponse
    case jobFailed
    case imageEncodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response."
        case .jobFailed: return "Face swap job failed."
        case .imageEncodingFailed: return "Could not encode image."
        case .network(let error): return error.localizedDescription
        }
    }
}

protocol FaceSwapServiceProtocol {
    func swap(_ request: FaceSwapRequest, progress: @escaping (Double) -> Void) async throws -> UIImage
}

enum FaceSwapServiceFactory {
    static func make() -> FaceSwapServiceProtocol {
        MorphAPIConfig.isConfigured ? RemoteFaceSwapService() : MockFaceSwapService()
    }
}

// MARK: - Mock (local compositing when API is not configured)

final class MockFaceSwapService: FaceSwapServiceProtocol {
    func swap(_ request: FaceSwapRequest, progress: @escaping (Double) -> Void) async throws -> UIImage {
        for step in 1...10 {
            try await Task.sleep(nanoseconds: 300_000_000)
            progress(Double(step) / 10.0)
        }
        return Self.compose(source: request.sourceImage, template: request.templateImage)
    }

    private static func compose(source: UIImage, template: UIImage) -> UIImage {
        let size = template.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            template.draw(in: CGRect(origin: .zero, size: size))

            let faceSize = CGSize(width: size.width * 0.42, height: size.height * 0.42)
            let faceOrigin = CGPoint(
                x: (size.width - faceSize.width) / 2,
                y: size.height * 0.18
            )
            let faceRect = CGRect(origin: faceOrigin, size: faceSize)

            context.cgContext.saveGState()
            context.cgContext.addEllipse(in: faceRect.insetBy(dx: -4, dy: -4))
            context.cgContext.clip()
            source.draw(in: faceRect)
            context.cgContext.restoreGState()

            context.cgContext.setBlendMode(.softLight)
            UIColor.white.withAlphaComponent(0.12).setFill()
            context.cgContext.fill(faceRect)
        }
    }
}

// MARK: - Remote API

final class RemoteFaceSwapService: FaceSwapServiceProtocol {
    private struct CreateJobResponse: Decodable {
        let jobId: String

        enum CodingKeys: String, CodingKey {
            case jobId = "job_id"
        }
    }

    private struct JobStatusResponse: Decodable {
        let status: String
        let resultURL: String?

        enum CodingKeys: String, CodingKey {
            case status
            case resultURL = "result_url"
        }
    }

    func swap(_ request: FaceSwapRequest, progress: @escaping (Double) -> Void) async throws -> UIImage {
        guard let baseURL = MorphAPIConfig.baseURL,
              let apiKey = MorphAPIConfig.apiKey else {
            throw FaceSwapError.invalidResponse
        }

        progress(0.1)
        let jobId = try await createJob(baseURL: baseURL, apiKey: apiKey, request: request)
        progress(0.25)

        for attempt in 0..<30 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let status = try await fetchStatus(baseURL: baseURL, apiKey: apiKey, jobId: jobId)
            progress(0.25 + (Double(attempt + 1) / 30.0) * 0.65)

            switch status.status.lowercased() {
            case "completed":
                guard let urlString = status.resultURL, let url = URL(string: urlString) else {
                    throw FaceSwapError.invalidResponse
                }
                return try await downloadImage(from: url)
            case "failed":
                throw FaceSwapError.jobFailed
            default:
                continue
            }
        }
        throw FaceSwapError.jobFailed
    }

    private func createJob(baseURL: URL, apiKey: String, request: FaceSwapRequest) async throws -> String {
        let url = baseURL.appendingPathComponent("v1/face-swap")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try buildMultipartBody(
            boundary: boundary,
            request: request
        )

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FaceSwapError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(CreateJobResponse.self, from: data)
        return decoded.jobId
    }

    private func fetchStatus(baseURL: URL, apiKey: String, jobId: String) async throws -> JobStatusResponse {
        let url = baseURL.appendingPathComponent("v1/face-swap/\(jobId)")
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FaceSwapError.invalidResponse
        }
        return try JSONDecoder().decode(JobStatusResponse.self, from: data)
    }

    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let image = UIImage(data: data) else {
            throw FaceSwapError.invalidResponse
        }
        return image
    }

    private func buildMultipartBody(boundary: String, request: FaceSwapRequest) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append("\(value)\(lineBreak)".data(using: .utf8)!)
        }

        appendField(name: "template_id", value: request.templateId)
        appendField(name: "hd_quality", value: request.hdQuality ? "true" : "false")
        appendField(name: "face_enhancement", value: request.faceEnhancement ? "true" : "false")

        guard let sourceData = request.sourceImage.jpegData(compressionQuality: 0.9) else {
            throw FaceSwapError.imageEncodingFailed
        }

        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source_image\"; filename=\"source.jpg\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(sourceData)
        body.append(lineBreak.data(using: .utf8)!)

        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
}
