//
//  EditorView.swift
//  CleanCut
//
import SwiftUI

struct EditorView: View {
    var processedImage: ProcessedImage
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: { viewModel.reset() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    Spacer()
                    Text("Editor")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: save) {
                        Text(isSaving ? "Saving…" : "Save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#2C7BE5"))
                            .padding(10)
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Image preview
                GeometryReader { geo in
                    ZStack {
                        CheckeredBackground()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Image(uiImage: composited())
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(20)
                }

                // Background picker
                BackgroundPickerView(selected: processedImage.background) { bg in
                    viewModel.updateBackground(bg)
                }
                .padding(.bottom, 30)
            }

            // Processing overlay
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Removing background…")
                            .foregroundColor(.white)
                        Text("\(Int(viewModel.processingProgress * 100))%")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ActivityView(image: img)
            }
        }
    }

    private func composited() -> UIImage {
        switch processedImage.background {
        case .transparent: return processedImage.processed
        case .white:       return draw(processedImage.processed, on: .white)
        case .black:       return draw(processedImage.processed, on: .black)
        case .custom:      return draw(processedImage.processed, on: processedImage.customColor)
        }
    }

    private func draw(_ image: UIImage, on color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }

    private func save() {
        isSaving = true
        Task {
            await viewModel.saveToPhotos()
            await MainActor.run { isSaving = false }
        }
    }
}

struct CheckeredBackground: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let tileSize: CGFloat = 16
                let cols = Int(size.width / tileSize) + 1
                let rows = Int(size.height / tileSize) + 1
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isLight = (row + col) % 2 == 0
                        context.fill(
                            Path(CGRect(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize, width: tileSize, height: tileSize)),
                            with: .color(isLight ? Color(white: 0.85) : Color(white: 0.7))
                        )
                    }
                }
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
