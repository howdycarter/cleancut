//
//  AIViews.swift
//
//  AI feature module — Chat, Image Generation, and Vision.
//  Gated by FeatureFlags.aiFeatures. To disable, set aiFeatures = false
//  in FeatureFlags and this entire module becomes inactive.
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - AI Chat View

struct AIChatView: View {
    struct ChatMessage: Identifiable, Hashable { let id = UUID(); let role: String; let content: String }
    @State private var messages: [ChatMessage] = [
        .init(role: "assistant", content: "Hi! Ask me anything.")
    ]
    @State private var input: String = ""
    @State private var isSending: Bool = false
    private let api = AIApiClient()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.md)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            composer
        }
        .navigationTitle(String(localized: "ai.chat.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var composer: some View {
        HStack(spacing: DS.Spacing.sm) {
            TextField(String(localized: "ai.chat.placeholder"), text: $input, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button(action: send) {
                if isSending { ProgressView() } else { Image(systemName: "paperplane.fill") }
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.all, DS.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(.init(role: "user", content: text))
        isSending = true
        Task {
            do {
                let reply = try await api.sendChat(messages: messages.map { .init(role: $0.role, content: $0.content) })
                await MainActor.run {
                    messages.append(.init(role: "assistant", content: reply))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    messages.append(.init(role: "assistant", content: "Error: \(error.localizedDescription)"))
                    isSending = false
                }
            }
        }
    }
}

private struct ChatBubble: View {
    let message: AIChatView.ChatMessage
    var isUser: Bool { message.role == "user" }
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: DS.Spacing.xl) }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(message.content)
                    .foregroundColor(isUser ? .white : DS.Colors.textPrimary)
                    .padding(.vertical, DS.Spacing.sm)
                    .padding(.horizontal, DS.Spacing.md)
                    .background(isUser ? DS.accent : DS.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !isUser { Spacer(minLength: DS.Spacing.xl) }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }
}

// MARK: - AI Image Generation View

struct AIImageGenView: View {
    @State private var prompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var images: [GeneratedImage] = []
    private let api = AIApiClient()
    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    struct GeneratedImage: Identifiable, Hashable { let id = UUID(); let uiImage: UIImage? }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                TextField(String(localized: "ai.images.placeholder"), text: $prompt)
                    .textFieldStyle(.roundedBorder)
                Button(action: generate) {
                    if isGenerating { ProgressView() } else { Text(String(localized: "ai.images.generate")) }
                }
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
            .padding(.horizontal)

            if images.isEmpty {
                DSEmptyState(title: String(localized: "ai.images.empty"), systemImage: "photo.on.rectangle")
            } else {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: DS.Spacing.sm) {
                        ForEach(images) { img in
                            ZStack {
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(DS.Colors.surfaceSecondary)
                                if let ui = img.uiImage {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    VStack(spacing: DS.Spacing.sm) {
                                        Image(systemName: "photo")
                                        Text("Generated")
                                            .appFont(.caption)
                                            .foregroundColor(DS.Colors.textSecondary)
                                    }
                                }
                            }
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(String(localized: "ai.images.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        isGenerating = true
        Task {
            do {
                let datas = try await api.generateImages(prompt: prompt, count: 4)
                let imgs = datas.map { UIImage(data: $0) }
                await MainActor.run {
                    images = imgs.map { .init(uiImage: $0) }
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    images = []
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - AI Vision View

struct AIVisionView: View {
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var uiImage: UIImage? = nil
    @State private var analysis: String? = nil
    @State private var isAnalyzing: Bool = false
    @State private var showCamera: Bool = false
    private let api = AIApiClient()

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(String(localized: "ai.vision.choose"), systemImage: "photo")
                }
                Button { showCamera = true } label: {
                    Label(String(localized: "ai.vision.camera"), systemImage: "camera")
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
            .padding(.horizontal)

            Group {
                if let ui = uiImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .padding(.horizontal)
                } else {
                    DSEmptyState(title: String(localized: "ai.vision.empty"), systemImage: "viewfinder")
                }
            }

            Button(action: analyze) {
                if isAnalyzing { ProgressView() } else { Text(String(localized: "ai.vision.analyze")) }
            }
            .disabled(uiImage == nil || isAnalyzing)

            if let text = analysis {
                Text(text)
                    .appFont(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .padding(.horizontal)
            }
            Spacer()
        }
        .navigationTitle(String(localized: "ai.vision.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in
                uiImage = img
                imageData = img?.jpegData(compressionQuality: 0.85)
            }
        }
        .onChange(of: pickedItem) { _ in loadTransfer() }
    }

    private func loadTransfer() {
        guard let item = pickedItem else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        imageData = data
                        uiImage = UIImage(data: data)
                        analysis = nil
                    }
                }
            } catch {
                print("PhotosPicker error: \(error)")
            }
        }
    }

    private func analyze() {
        guard let data = imageData else { return }
        isAnalyzing = true
        Task {
            do {
                let text = try await api.visionAnalyze(imageData: data)
                await MainActor.run {
                    analysis = text
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    analysis = "Error: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

// MARK: - UIKit Camera Bridge

struct ImagePicker: UIViewControllerRepresentable {
    enum Source { case camera, library }
    var sourceType: UIImagePickerController.SourceType
    var onPicked: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { self.onPicked(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onPicked(nil) }
        }
    }
}
