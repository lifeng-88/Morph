import CoreImage
import UIKit

enum SmartDrawStyle: String, CaseIterable, Identifiable {
    case sketch
    case ink
    case neon
    case watercolor
    case anime
    case chibi

    var id: String { rawValue }

    var nameKey: String { "draw.style.\(rawValue)" }

    var icon: String {
        switch self {
        case .sketch: return "pencil.line"
        case .ink: return "paintbrush.pointed"
        case .neon: return "bolt.fill"
        case .watercolor: return "drop.fill"
        case .anime: return "sparkles"
        case .chibi: return "face.smiling"
        }
    }

    var coinCost: Int {
        switch self {
        case .sketch: return 25
        case .ink: return 25
        case .neon: return 35
        case .watercolor: return 30
        case .anime: return 45
        case .chibi: return 50
        }
    }
}

struct SmartDrawRequest {
    let sourceImage: UIImage
    let style: SmartDrawStyle
}

enum SmartDrawError: LocalizedError {
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .processingFailed: return L10n.drawSmartFailed
        }
    }
}

protocol SmartDrawServiceProtocol {
    func generate(_ request: SmartDrawRequest, progress: @escaping (Double) -> Void) async throws -> UIImage
}

enum SmartDrawServiceFactory {
    static func make() -> SmartDrawServiceProtocol {
        LocalSmartDrawService()
    }
}

final class LocalSmartDrawService: SmartDrawServiceProtocol {
    private let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: true
    ])

    func generate(_ request: SmartDrawRequest, progress: @escaping (Double) -> Void) async throws -> UIImage {
        let prepared = request.sourceImage.preparedForProcessing(maxDimension: 1400)
        progress(0.15)

        for step in 1...5 {
            try await Task.sleep(nanoseconds: 180_000_000)
            progress(0.15 + Double(step) / 5.0 * 0.75)
        }

        guard let ciImage = CIImage(image: prepared),
              let output = styledImage(from: normalizedInput(ciImage), style: request.style),
              let cgImage = context.createCGImage(output, from: output.extent.integral) else {
            throw SmartDrawError.processingFailed
        }

        progress(1.0)
        return UIImage(cgImage: cgImage, scale: prepared.scale, orientation: .up)
    }

    private func styledImage(from image: CIImage, style: SmartDrawStyle) -> CIImage? {
        switch style {
        case .sketch: return sketchStyle(image)
        case .ink: return inkStyle(image)
        case .neon: return neonStyle(image)
        case .watercolor: return watercolorStyle(image)
        case .anime: return animeStyle(image)
        case .chibi: return chibiStyle(image)
        }
    }

    // MARK: - Preprocessing

    private func normalizedInput(_ image: CIImage) -> CIImage {
        image
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 0.85,
                "inputShadowAmount": 0.35
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.05,
                kCIInputSaturationKey: 1.08
            ])
    }

    // MARK: - Styles

    private func sketchStyle(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        let tonal = image
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 0.78,
                kCIInputBrightnessKey: 0.18
            ])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 6.0])

        let lines = lineOverlay(from: image, edgeIntensity: 0.95, threshold: 0.11, contrast: 42)
        let paper = paperColor(red: 0.97, green: 0.96, blue: 0.94).cropped(to: extent)

        let washed = tonal.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: paper
        ])
        let sketched = lines.applyingFilter("CIMultiplyBlendMode", parameters: [
            kCIInputBackgroundImageKey: washed
        ])
        return sharpen(sketched, radius: 1.2, intensity: 0.35).cropped(to: extent)
    }

    private func inkStyle(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        let lines = lineOverlay(from: image, edgeIntensity: 1.1, threshold: 0.1, contrast: 48)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.4,
                kCIInputBrightnessKey: -0.22,
                kCIInputSaturationKey: 0.0
            ])

        let paper = paperColor(red: 1, green: 1, blue: 1).cropped(to: extent)
        return lines
            .applyingFilter("CIMultiplyBlendMode", parameters: [
                kCIInputBackgroundImageKey: paper
            ])
            .cropped(to: extent)
    }

    private func neonStyle(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        let edges = image.applyingFilter("CIEdges", parameters: [
            kCIInputIntensityKey: 4.5
        ])

        let pinkGlow = edges
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 2.5])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5])
            .applyingFilter("CIFalseColor", parameters: [
                "inputColor0": CIColor(red: 0.04, green: 0.03, blue: 0.1),
                "inputColor1": CIColor(red: 1.0, green: 0.35, blue: 0.55)
            ])

        let cyanCore = edges.applyingFilter("CIFalseColor", parameters: [
            "inputColor0": CIColor(red: 0.04, green: 0.03, blue: 0.1),
            "inputColor1": CIColor(red: 0.35, green: 0.85, blue: 1.0)
        ])

        let background = radialBackground(extent: extent)
        let combined = cyanCore
            .applyingFilter("CIScreenBlendMode", parameters: [
                kCIInputBackgroundImageKey: pinkGlow
            ])
            .applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: 8.0,
                kCIInputIntensityKey: 0.55
            ])

        return combined
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: background
            ])
            .cropped(to: extent)
    }

    private func watercolorStyle(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        let bleed = image
            .applyingFilter("CIMedianFilter")
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3.5])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.25,
                kCIInputContrastKey: 0.88,
                kCIInputBrightnessKey: 0.06
            ])
            .applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: 10.0,
                kCIInputIntensityKey: 0.35
            ])

        let pigment = bleed.applyingFilter("CIColorPosterize", parameters: [
            "inputLevels": 10.0
        ])

        let edges = lineOverlay(from: image, edgeIntensity: 0.55, threshold: 0.18, contrast: 28)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.8,
                kCIInputBrightnessKey: -0.35,
                kCIInputSaturationKey: 0.2
            ])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.4])

        let paper = paperColor(red: 0.98, green: 0.97, blue: 0.95).cropped(to: extent)
        let painted = pigment.composited(over: paper)
        return edges
            .applyingFilter("CIMultiplyBlendMode", parameters: [
                kCIInputBackgroundImageKey: painted
            ])
            .cropped(to: extent)
    }

    private func animeStyle(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        let colorBase = celColorLayer(from: image, blur: 2.0, levels: 9, saturation: 1.38)
        let lines = lineOverlay(from: image, edgeIntensity: 0.9, threshold: 0.13, contrast: 40)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.5,
                kCIInputBrightnessKey: -0.18,
                kCIInputSaturationKey: 0.0
            ])

        let shaded = lines.applyingFilter("CIMultiplyBlendMode", parameters: [
            kCIInputBackgroundImageKey: colorBase
        ])

        let highlights = image
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 1.2
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: 0.12,
                kCIInputContrastKey: 1.3
            ])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4.0])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.22)
            ])

        let withShine = highlights.applyingFilter("CIScreenBlendMode", parameters: [
            kCIInputBackgroundImageKey: shaded
        ])

        return sharpen(
            withShine.applyingFilter("CIVibrance", parameters: ["inputAmount": 0.42]),
            radius: 1.5,
            intensity: 0.28
        ).cropped(to: extent)
    }

    private func chibiStyle(_ image: CIImage) -> CIImage? {
        let extent = image.extent
        let headCenter = CGPoint(x: extent.midX, y: extent.midY + extent.height * 0.14)
        let bodyCenter = CGPoint(x: extent.midX, y: extent.midY - extent.height * 0.22)

        let bulged = image.applyingFilter("CIBumpDistortion", parameters: [
            "inputCenter": CIVector(cgPoint: headCenter),
            kCIInputRadiusKey: extent.width * 0.34,
            "inputScale": 0.28
        ]).applyingFilter("CIPinchDistortion", parameters: [
            "inputCenter": CIVector(cgPoint: bodyCenter),
            kCIInputRadiusKey: extent.width * 0.42,
            "inputScale": -0.12
        ])

        let colorBase = celColorLayer(from: bulged, blur: 2.8, levels: 7, saturation: 1.55)
            .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.48])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.05, y: 0.02, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.01, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.95, w: 0),
                "inputBiasVector": CIVector(x: 0.025, y: 0.02, z: 0.015, w: 0)
            ])

        let lines = lineOverlay(from: bulged, edgeIntensity: 0.75, threshold: 0.15, contrast: 34)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.0,
                kCIInputBrightnessKey: -0.2,
                kCIInputSaturationKey: 0.0
            ])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.5])

        let outlined = lines.applyingFilter("CIMultiplyBlendMode", parameters: [
            kCIInputBackgroundImageKey: colorBase
        ])

        let blush = bulged
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 18.0])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.8,
                kCIInputBrightnessKey: 0.15
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.2, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0.6, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.6, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.12)
            ])

        return sharpen(
            blush.applyingFilter("CIScreenBlendMode", parameters: [
                kCIInputBackgroundImageKey: outlined
            ]),
            radius: 1.3,
            intensity: 0.22
        ).cropped(to: extent)
    }

    // MARK: - Filter helpers

    private func lineOverlay(
        from image: CIImage,
        edgeIntensity: Double,
        threshold: Double,
        contrast: Double
    ) -> CIImage {
        image.applyingFilter("CILineOverlay", parameters: [
            "inputNRNoiseLevel": 0.06,
            "inputNRSharpness": 0.78,
            "inputEdgeIntensity": edgeIntensity,
            "inputThreshold": threshold,
            "inputContrast": contrast
        ])
    }

    private func celColorLayer(
        from image: CIImage,
        blur: Double,
        levels: Double,
        saturation: Double
    ) -> CIImage {
        image
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: saturation,
                kCIInputContrastKey: 1.08,
                kCIInputBrightnessKey: 0.04
            ])
            .applyingFilter("CIColorPosterize", parameters: [
                "inputLevels": levels
            ])
    }

    private func sharpen(_ image: CIImage, radius: Double, intensity: Double) -> CIImage {
        image.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: radius,
            kCIInputIntensityKey: intensity
        ])
    }

    private func radialBackground(extent: CGRect) -> CIImage {
        let fallback = CIImage(color: CIColor(red: 0.04, green: 0.03, blue: 0.1)).cropped(to: extent)
        guard let filter = CIFilter(name: "CIRadialGradient") else { return fallback }

        filter.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: "inputCenter")
        filter.setValue(extent.width * 0.15, forKey: "inputRadius0")
        filter.setValue(max(extent.width, extent.height) * 0.85, forKey: "inputRadius1")
        filter.setValue(CIColor(red: 0.1, green: 0.07, blue: 0.18), forKey: "inputColor0")
        filter.setValue(CIColor(red: 0.03, green: 0.02, blue: 0.08), forKey: "inputColor1")

        return filter.outputImage?.cropped(to: extent) ?? fallback
    }

    private func paperColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
    }
}

private extension UIImage {
    func preparedForProcessing(maxDimension: CGFloat) -> UIImage {
        let normalized = normalizedOrientation()
        let size = normalized.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return normalized }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension CGRect {
    var integral: CGRect {
        CGRect(
            x: floor(origin.x),
            y: floor(origin.y),
            width: ceil(width),
            height: ceil(height)
        )
    }
}
