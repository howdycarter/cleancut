//
//  PhotoEditorViewModel.swift
//  CleanCut
//
import SwiftUI
import PhotosUI
import Photos

@MainActor
class PhotoEditorViewModel: ObservableObject {
    @Published var processedImage: ProcessedImage?
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var errorMessage: String?
    @Published var showingPhotoPicker = false
    @Published var isPremium = false

    private let bgService = BackgroundRemovalService.shared

    func loadImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            errorMessage = "Could not load the selected image."
            return
        }
        await process(image: uiImage)
    }

    func process(image: UIImage) async {
        isProcessing = true
        processingProgress = 0
        processedImage = nil

        // Animate progress
        let progressTask = Task {
            for i in 0...85 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                processingProgress = Double(i) / 100.0
            }
        }

        do {
            let result = try await bgService.removeBackground(from: image)
            progressTask.cancel()
            processingProgress = 1.0
            try? await Task.sleep(nanoseconds: 200_000_000)
            processedImage = ProcessedImage(original: image, processed: result)
        } catch {
            progressTask.cancel()
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func updateBackground(_ bg: BackgroundType) {
        guard var current = processedImage else { return }
        current.background = bg
        processedImage = current
    }

    func composited() async -> UIImage? {
        guard let img = processedImage else { return nil }
        return await bgService.compositeOnBackground(img.processed, background: img.background, color: img.customColor)
    }

    func saveToPhotos() async {
        guard let img = await composited() else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }
        } catch {
            errorMessage = "Could not save image: \(error.localizedDescription)"
        }
    }

    func reset() {
        processedImage = nil
        processingProgress = 0
    }
}
