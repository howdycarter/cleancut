import SwiftUI
import PhotosUI
import Photos

@MainActor
final class PhotoEditorViewModel: ObservableObject {
    @Published var processedImage: ProcessedImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingPhotoPicker = false
    @Published var isPremium = false

    private let bgService = BackgroundRemovalService.shared

    func loadImage(from item: PhotosPickerItem) async {
        guard !isProcessing else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                errorMessage = "Could not load this photo. Please choose another image."
                return
            }
            await process(image: image)
        } catch {
            errorMessage = "Could not download this photo. Check your connection and try again."
        }
    }

    func process(image: UIImage) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            let result = try await bgService.removeBackground(from: image)
            processedImage = ProcessedImage(original: image, processed: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateBackground(_ background: BackgroundType) {
        guard background != .custom || isPremium else { return }
        processedImage?.background = background
    }

    func updateCustomColor(_ color: UIColor) {
        processedImage?.customColor = color
    }

    func composited() -> UIImage? {
        guard let image = processedImage else { return nil }
        let background: BackgroundType = !isPremium && image.background == .custom ? .transparent : image.background
        let output = bgService.compositeOnBackground(image.processed, background: background, color: image.customColor)
        guard !isPremium, max(output.size.width * output.scale, output.size.height * output.scale) > 1_024 else { return output }
        let ratio = 1_024 / max(output.size.width, output.size.height)
        let size = CGSize(width: output.size.width * ratio, height: output.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            output.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    @discardableResult
    func saveToPhotos() async -> Bool {
        guard let image = composited(), let data = image.pngData() else { return false }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            errorMessage = "Allow CleanCut to add photos in Settings, or use Share to export your image."
            return false
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = "public.png"
                request.addResource(with: .photo, data: data, options: options)
            }
            return true
        } catch {
            errorMessage = "Could not save your image. Please try again or use Share."
            return false
        }
    }

    func reset() { processedImage = nil }
}
