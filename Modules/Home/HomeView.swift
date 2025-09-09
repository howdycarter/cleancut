//
//  HomeView.swift
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @Environment(\.appTheme) private var theme
    @StateObject private var vm = HomeViewModel()
    @State private var isShowingShowcase: Bool = false
    @State private var profile: Profile?

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: 2) }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                HeaderCard(profile: profile)
                menuSection
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .task { await loadProfile() }
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("AI Wrappers")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
                HomeMenuButton(title: "Text Generation", systemImage: "text.bubble.fill") {
                    router.push(.aiChat)
                }
                HomeMenuButton(title: "Image Generation", systemImage: "photo.on.rectangle") {
                    router.push(.aiImages)
                }
                HomeMenuButton(title: "Vision (Image → Text)", systemImage: "viewfinder") {
                    router.push(.aiVision)
                }
            }
        }
    }

    private func loadProfile() async {
        guard container.config.featureFlags.auth else { return }
        if let user = await container.authRepository.currentUser() {
            do { profile = try await container.profileRepository.fetchProfile(for: user.id) }
            catch { profile = nil }
        }
    }
}

private struct HomeCell: View {
    let item: HomeViewModel.Item
    @Environment(\.appTheme) private var theme
    var body: some View {
        Text(item.title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(DesignTokens.Spacing.md)
            .foregroundColor(theme.isGlass ? .primary : DesignTokens.primaryColor)
            .background(
                Group {
                    if theme.isGlass {
                        Color.clear
                    } else {
                        DesignTokens.primaryColor.opacity(0.08)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .if(theme.isGlass) { view in
                view.glassCard(cornerRadius: DesignTokens.Radius.md)
            }
            .accessibilityLabel(Text("home.item.access"))
    }
}

// Subscription management via StoreKit removed. Status still displays in ProfileSummary.

// MARK: - Home Menu Button

private struct HomeMenuButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void
    @Environment(\.appTheme) private var theme
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(DesignTokens.accentColor)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(theme.isGlass ? Color.clear : DesignTokens.primaryColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .if(theme.isGlass) { view in view.glassCard(cornerRadius: DesignTokens.Radius.md) }
        }
        .buttonStyle(.plain)
    }
}

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
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            composer
        }
        .navigationTitle("Text Generation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Type a message", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button(action: send) {
                if isSending { ProgressView() } else { Image(systemName: "paperplane.fill") }
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.all, 12)
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
            if isUser { Spacer(minLength: 24) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .foregroundColor(isUser ? .white : .primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isUser ? DesignTokens.accentColor : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !isUser { Spacer(minLength: 24) }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }
}

// MARK: - AI Image Generation View

struct AIImageGenView: View {
    @State private var prompt: String = "A scenic sunset over mountains"
    @State private var isGenerating: Bool = false
    @State private var images: [GeneratedImage] = []
    private let api = AIApiClient()
    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    struct GeneratedImage: Identifiable, Hashable { let id = UUID(); let uiImage: UIImage? }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Describe an image", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                Button(action: generate) {
                    if isGenerating { ProgressView() } else { Text("Generate") }
                }
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
            .padding(.horizontal)

            if images.isEmpty {
                EmptyStateView(title: "No images yet", systemImage: "photo.on.rectangle")
            } else {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(images) { img in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                if let ui = img.uiImage {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                        Text("Generated")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Image Generation")
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
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                }
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera")
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                } else {
                    EmptyStateView(title: "No image selected", systemImage: "viewfinder")
                }
            }

            Button(action: analyze) {
                if isAnalyzing { ProgressView() } else { Text("Analyze Image") }
            }
            .disabled(uiImage == nil || isAnalyzing)

            if let text = analysis {
                Text(text)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
            }
            Spacer()
        }
        .navigationTitle("Vision")
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

// UIKit camera bridge
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

// MARK: - Simple empty state (iOS 16 compatible)

private struct EmptyStateView: View {
    var title: String
    var systemImage: String
    var description: String? = nil
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            if let description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileSummary: View {
    let profile: Profile
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure(_): Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary)
                    case .empty: ProgressView()
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundColor(.secondary)
                    .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name.isEmpty ? "" : profile.name).font(.headline)
                if !profile.contact.isEmpty { Text(profile.contact).foregroundColor(.secondary) }
                Text(profile.subscriptionStatus.rawValue)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct HeaderCard: View {
    let profile: Profile?
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.primaryColor.opacity(0.08))
            HStack(spacing: 16) {
                LogoView(size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    if let p = profile, !p.name.isEmpty {
                        Text("Welcome, \(p.name)")
                            .font(.headline)
                    } else {
                        Text("Welcome")
                            .font(.headline)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
    }
}

 
