import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    var processedImage: ProcessedImage
    var onUpgrade: () -> Void
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isSaving = false
    @State private var didSave = false

    private var previewBackground: Color {
        switch processedImage.background {
        case .transparent: return .clear
        case .white: return .white
        case .black: return .black
        case .custom: return viewModel.isPremium ? Color(uiColor: processedImage.customColor) : .clear
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { viewModel.reset() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Choose another photo")
                Spacer()
                Text("Editor").font(.headline)
                Spacer()
                Button {
                    shareImage = viewModel.composited()
                    showShareSheet = shareImage != nil
                } label: {
                    Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share PNG image")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)

            GeometryReader { geometry in
                let available = CGSize(width: max(1, geometry.size.width - 40), height: max(1, geometry.size.height - 40))
                let imageSize = processedImage.processed.size
                let scale = min(available.width / max(1, imageSize.width), available.height / max(1, imageSize.height))
                let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                ZStack {
                    CheckeredBackground()
                    Image(uiImage: processedImage.processed)
                        .resizable()
                        .scaledToFit()
                        .background(previewBackground)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .accessibilityLabel("Photo with selected background")
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(20)
            }

            BackgroundPickerView(selected: processedImage.background) { background in
                if background == .custom && !viewModel.isPremium { onUpgrade() }
                else { viewModel.updateBackground(background) }
            }
                .padding(.vertical, 12)

            if processedImage.background == .custom {
                ColorPicker("Background color", selection: Binding(
                    get: { Color(uiColor: processedImage.customColor) },
                    set: { viewModel.updateCustomColor(UIColor($0)) }
                ), supportsOpacity: false)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .foregroundStyle(.white)
            }

            if !viewModel.isPremium {
                Button("Unlock original resolution and custom colors with Pro", action: onUpgrade)
                    .font(.footnote)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                Text("Free PNG exports up to 1024 pixels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }

            Button {
                isSaving = true
                Task {
                    didSave = await viewModel.saveToPhotos()
                    isSaving = false
                }
            } label: {
                HStack {
                    if isSaving { ProgressView().tint(.black) }
                    else { Image(systemName: "square.and.arrow.down") }
                    Text(isSaving ? "Saving…" : "Save to Photos").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.black)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage { ActivityView(image: shareImage) }
        }
        .alert("Saved to Photos", isPresented: $didSave) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your image was saved as a PNG. Transparent backgrounds stay transparent.")
        }
    }
}

struct CheckeredBackground: View {
    var body: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 16
            for row in 0...Int(size.height / tileSize) {
                for column in 0...Int(size.width / tileSize) {
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * tileSize, y: CGFloat(row) * tileSize, width: tileSize, height: tileSize)),
                        with: .color(Color(white: (row + column).isMultiple(of: 2) ? 0.85 : 0.7))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [PNGShareItem(image: image)], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private final class PNGShareItem: NSObject, UIActivityItemSource {
    let image: UIImage
    init(image: UIImage) { self.image = image }
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { image }
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image.pngData() }
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String { UTType.png.identifier }
}
