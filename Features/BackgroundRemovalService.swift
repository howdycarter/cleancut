import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BackgroundRemovalError: LocalizedError {
    case invalidImage
    case segmentationFailed
    case maskApplicationFailed
    case processingUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not load the selected image."
        case .segmentationFailed: return "No clear subject was found. Try a photo with a person, pet, or object that stands out from the background."
        case .maskApplicationFailed: return "Could not apply the background mask. Please try another photo."
        case .processingUnavailable: return "Background removal is unavailable right now. Please try another photo or restart CleanCut."
        }
    }
}

actor BackgroundRemovalService {
    static let shared = BackgroundRemovalService()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private init() {}

    func removeBackground(from image: UIImage) async throws -> UIImage {
        try Task.checkCancellation()
        let normalized = Self.normalizedImage(image)
        guard let cgImage = normalized.cgImage else { throw BackgroundRemovalError.invalidImage }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try Task.checkCancellation()
            try handler.perform([request])
            try Task.checkCancellation()
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                throw BackgroundRemovalError.segmentationFailed
            }
            let mask = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
            try Task.checkCancellation()
            let result = try applyMask(to: cgImage, maskBuffer: mask)
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BackgroundRemovalError {
            throw error
        } catch {
            throw BackgroundRemovalError.processingUnavailable
        }
    }

    /// Draw orientation metadata into the pixels before Vision reads the image.
    nonisolated static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func applyMask(to cgImage: CGImage, maskBuffer: CVPixelBuffer) throws -> UIImage {
        let original = CIImage(cgImage: cgImage)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let scaledMask = mask.transformed(by: CGAffineTransform(scaleX: original.extent.width / mask.extent.width, y: original.extent.height / mask.extent.height))
        let blend = CIFilter.blendWithMask()
        blend.inputImage = original
        blend.maskImage = scaledMask
        blend.backgroundImage = CIImage(color: .clear).cropped(to: original.extent)
        guard let output = blend.outputImage,
              let result = ciContext.createCGImage(output, from: original.extent) else {
            throw BackgroundRemovalError.maskApplicationFailed
        }
        return UIImage(cgImage: result)
    }

    nonisolated func compositeOnBackground(_ image: UIImage, background: BackgroundType, color: UIColor = .white) -> UIImage {
        switch background {
        case .transparent: return image
        case .white: return drawOnColor(image, color: .white)
        case .black: return drawOnColor(image, color: .black)
        case .custom: return drawOnColor(image, color: color)
        }
    }

    private nonisolated func drawOnColor(_ image: UIImage, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }
}
