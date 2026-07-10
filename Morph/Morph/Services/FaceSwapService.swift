import CoreImage
import UIKit
import Vision

struct FaceSwapRequest {
    let sourceImage: UIImage
    let templateId: String
    let templateImage: UIImage
    let templateCategoryKey: String
    let hdQuality: Bool
    let faceEnhancement: Bool
}

enum FaceSwapError: LocalizedError {
    case invalidResponse
    case jobFailed
    case imageEncodingFailed
    case consentRequired
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response."
        case .jobFailed: return "Face swap job failed."
        case .imageEncodingFailed: return "Could not encode image."
        case .consentRequired: return L10n.aiConsentRequiredError
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
        return LocalFaceSwapCompositor.compose(
            source: request.sourceImage,
            template: request.templateImage,
            categoryKey: request.templateCategoryKey,
            faceEnhancement: request.faceEnhancement
        )
    }
}

private enum LocalFaceSwapCompositor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func compose(
        source: UIImage,
        template: UIImage,
        categoryKey: String,
        faceEnhancement: Bool
    ) -> UIImage {
        let sourceImage = normalized(source)
        let templateImage = normalized(template)
        let drawStyle = SmartDrawStyle.forTemplateCategory(categoryKey)

        var result = SmartDrawImageProcessor.generateFromSource(
            source: sourceImage,
            style: drawStyle,
            templateStyleReference: templateImage
        )

        if let sourceFace = detectPrimaryFaceRect(in: sourceImage),
           let templateFace = detectPrimaryFaceRect(in: templateImage) {
            let patchRect = expand(sourceFace, horizontal: 0.3, vertical: 0.36)
                .intersection(CGRect(origin: .zero, size: sourceImage.size))
            guard patchRect.width > 1, patchRect.height > 1 else { return result }

            let facePatch = crop(result, rect: patchRect)
            let templateFacePatch = aspectFill(
                crop(templateImage, rect: expand(templateFace, horizontal: 0.32, vertical: 0.38)),
                into: patchRect.size
            )
            result = TemplateStyleProcessor.applyRegionalStyle(
                to: result,
                patch: facePatch,
                in: patchRect,
                reference: templateFacePatch,
                intensity: 0.62
            )
        }

        if faceEnhancement, let faceRect = detectPrimaryFaceRect(in: sourceImage) {
            result = enhanceFaceRegion(in: result, faceRect: faceRect)
        }

        return result
    }

    private static func enhanceFaceRegion(in image: UIImage, faceRect: CGRect) -> UIImage {
        let patchRect = expand(faceRect, horizontal: 0.28, vertical: 0.34)
            .intersection(CGRect(origin: .zero, size: image.size))
        guard patchRect.width > 1, patchRect.height > 1 else { return image }

        let facePatch = crop(image, rect: patchRect)
        let enhanced = softenSkin(on: facePatch)
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            enhanced.draw(in: patchRect)
        }
    }

    private static func detectPrimaryFaceRect(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let orientation = cgOrientation(from: image.imageOrientation)
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }) else {
            return nil
        }

        return uiRect(fromVisionRect: face.boundingBox, imageSize: image.size)
    }

    private static func uiRect(fromVisionRect box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }

    private static func expand(_ rect: CGRect, horizontal: CGFloat, vertical: CGFloat) -> CGRect {
        rect.insetBy(dx: -rect.width * horizontal, dy: -rect.height * vertical)
    }

    private static func crop(_ image: UIImage, rect: CGRect) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let bounds = CGRect(origin: .zero, size: image.size)
        let cropRect = rect.intersection(bounds)
        guard cropRect.width > 1, cropRect.height > 1 else { return image }

        let scale = image.scale
        let pixelRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.size.width * scale,
            height: cropRect.size.height * scale
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return image }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    private static func aspectFill(_ image: UIImage, into targetSize: CGSize) -> UIImage {
        let widthScale = targetSize.width / image.size.width
        let heightScale = targetSize.height / image.size.height
        let scale = max(widthScale, heightScale)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - size.width) / 2,
            y: (targetSize.height - size.height) / 2
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: size))
        }
    }

    private static func softenSkin(on image: UIImage) -> UIImage {
        guard var ciImage = CIImage(image: image) else { return image }

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciImage, forKey: kCIInputImageKey)
            blur.setValue(0.8, forKey: kCIInputRadiusKey)
            if let blurred = blur.outputImage?.cropped(to: ciImage.extent) {
                ciImage = blurred
            }
        }

        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(ciImage, forKey: kCIInputImageKey)
            sharpen.setValue(0.35, forKey: kCIInputSharpnessKey)
            if let output = sharpen.outputImage {
                ciImage = output
            }
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
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
        guard AIDataConsentManager.hasGranted else {
            throw FaceSwapError.consentRequired
        }

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
