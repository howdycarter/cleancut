import SwiftUI
import PhotosUI
import Photos

struct PNGExport: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}

@MainActor
final class PhotoEditorViewModel: ObservableObject {
    @Published var processedImage: ProcessedImage?
    @Published private(set) var isProcessing = false
    @Published private(set) var processingMessage = ""
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var showingPhotoPicker = false
    @Published var isPremium = false

    private let bgService = BackgroundRemovalService.shared
    private let removeBackground: (UIImage) async throws -> UIImage
    private let requestPhotoAuthorization: () async -> PHAuthorizationStatus
    private let savePNG: (Data) async throws -> Void
    private let encodePNG: (UIImage) -> Data?
    private var processingTask: Task<Void, Never>?
    private var activeImportID: UUID?

    init(
        removeBackground: @escaping (UIImage) async throws -> UIImage = {
            try await BackgroundRemovalService.shared.removeBackground(from: $0)
        },
        requestPhotoAuthorization: @escaping () async -> PHAuthorizationStatus = {
            await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        },
        savePNG: @escaping (Data) async throws -> Void = { data in
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = "public.png"
                request.addResource(with: .photo, data: data, options: options)
            }
        },
        encodePNG: @escaping (UIImage) -> Data? = { $0.pngData() }
    ) {
        self.removeBackground = removeBackground
        self.requestPhotoAuthorization = requestPhotoAuthorization
        self.savePNG = savePNG
        self.encodePNG = encodePNG
    }

    @discardableResult
    func loadImage(from item: PhotosPickerItem) -> Task<Void, Never> {
        loadImage { try await item.loadTransferable(type: Data.self) }
    }

    /// The loader is injectable so slow iCloud loads and failed downloads can be tested.
    /// Starting a newer import immediately invalidates any older completion.
    @discardableResult
    func loadImage(using loader: @escaping () async throws -> Data?) -> Task<Void, Never> {
        startImport(message: "Loading photo…") {
            let data: Data?
            do {
                data = try await loader()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw PhotoImportError.downloadFailed
            }
            try Task.checkCancellation()
            guard let data, let image = UIImage(data: data) else {
                throw PhotoImportError.invalidImage
            }
            return image
        }
    }

    @discardableResult
    func process(image: UIImage) -> Task<Void, Never> {
        startImport(message: "Removing background…") { image }
    }

    private func startImport(message: String, load: @escaping () async throws -> UIImage) -> Task<Void, Never> {
        cancelProcessing()
        let importID = UUID()
        activeImportID = importID
        isProcessing = true
        processingMessage = message
        errorMessage = nil
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.finishImport(importID) }
            do {
                try Task.checkCancellation()
                let image = try await load()
                try Task.checkCancellation()
                guard self.activeImportID == importID else { return }
                self.processingMessage = "Removing background…"
                let result = try await self.removeBackground(image)
                try Task.checkCancellation()
                guard self.activeImportID == importID else { return }
                self.processedImage = ProcessedImage(original: image, processed: result)
            } catch is CancellationError {
                // Cancelling an import is a normal user action, not an error alert.
            } catch {
                guard !Task.isCancelled, self.activeImportID == importID else { return }
                self.errorMessage = error.localizedDescription
            }
        }
        processingTask = task
        return task
    }

    func cancelProcessing() {
        activeImportID = nil
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
        processingMessage = ""
    }

    private func finishImport(_ importID: UUID) {
        guard activeImportID == importID else { return }
        activeImportID = nil
        processingTask = nil
        isProcessing = false
        processingMessage = ""
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

    /// Save and Share use the same already-encoded PNG, including the free export limit.
    func prepareExport() -> PNGExport? {
        guard let image = composited() else {
            errorMessage = "Choose a photo before exporting."
            return nil
        }
        guard let data = encodePNG(image) else {
            errorMessage = "Could not prepare your PNG. Please try again or choose another photo."
            return nil
        }
        errorMessage = nil
        return PNGExport(image: image, data: data)
    }

    @discardableResult
    func saveToPhotos() async -> Bool {
        guard !isSaving, !isProcessing, !Task.isCancelled else { return false }
        guard let sourceID = processedImage?.id, let export = prepareExport() else {
            if processedImage == nil { errorMessage = "Choose a photo before exporting." }
            return false
        }
        isSaving = true
        defer { isSaving = false }
        let authorization = await requestPhotoAuthorization()
        guard !Task.isCancelled, processedImage?.id == sourceID else { return false }
        guard authorization == .authorized || authorization == .limited else {
            errorMessage = "Allow CleanCut to add photos in Settings, or use Share to export your image."
            return false
        }
        do {
            try await savePNG(export.data)
            // A system write already submitted cannot be undone, but an old editor
            // must not show a success/error alert over a newer photo.
            return !Task.isCancelled && processedImage?.id == sourceID
        } catch {
            guard !Task.isCancelled, processedImage?.id == sourceID else { return false }
            errorMessage = "Could not save your image. Please try again or use Share."
            return false
        }
    }

    func reset() {
        cancelProcessing()
        processedImage = nil
        errorMessage = nil
    }
}

private enum PhotoImportError: LocalizedError {
    case invalidImage
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not load this photo. Please choose another image."
        case .downloadFailed: return "Could not download this photo. Check your connection and try again."
        }
    }
}
