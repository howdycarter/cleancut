//
//  BackgroundRemovalService.swift
//  CleanCut
//
import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BackgroundRemovalError: LocalizedError {
    case invalidImage
    case segmentationFailed
    case maskApplicationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:          return "Could not load the selected image."
        case .segmentationFailed:    return "Background detection failed. Try a photo with a clear subject."
        case .maskApplicationFailed: return "Could not apply the background mask."
        }
    }
}

actor BackgroundRemovalService {
    static let shared = BackgroundRemovalService()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw BackgroundRemovalError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let result = request.results?.first else {
                    continuation.resume(throwing: BackgroundRemovalError.segmentationFailed)
                    return
                }
                do {
                    let output = try self.applyMask(to: cgImage, maskBuffer: result.pixelBuffer)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func applyMask(to cgImage: CGImage, maskBuffer: CVPixelBuffer) throws -> UIImage {
        let original  = CIImage(cgImage: cgImage)
        let rawMask   = CIImage(cvPixelBuffer: maskBuffer)

        let scaleX = original.extent.width  / rawMask.extent.width
        let scaleY = original.extent.height / rawMask.extent.height
        let scaledMask = rawMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let blend = CIFilter.blendWithMask()
        blend.inputImage      = original
        blend.maskImage       = scaledMask
        blend.backgroundImage = CIImage.empty()

        guard let output = blend.outputImage else {
            throw BackgroundRemovalError.maskApplicationFailed
        }
        guard let result = ciContext.createCGImage(output, from: original.extent) else {
            throw BackgroundRemovalError.maskApplicationFailed
        }
        return UIImage(cgImage: result)
    }

    func compositeOnBackground(_ image: UIImage, background: BackgroundType, color: UIColor = .white) -> UIImage {
        switch background {
        case .transparent:
            return image
        case .white:
            return drawOnColor(image, color: .white)
        case .black:
            return drawOnColor(image, color: .black)
        case .custom:
            return drawOnColor(image, color: color)
        }
    }

    private func drawOnColor(_ image: UIImage, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }
}
