//
//  HomeView.swift
//  CleanCut
//

import SwiftUI
import PhotosUI
import AVFoundation

struct HomeView: View {
    @Environment(\.container) private var container
    @StateObject private var viewModel = PhotoEditorViewModel()
    @State private var isShowingPaywall = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let result = viewModel.processedImage {
                EditorView(processedImage: result, onUpgrade: { isShowingPaywall = true }, viewModel: viewModel)
            } else {
                homeContent.disabled(viewModel.isProcessing)
            }
            if viewModel.isProcessing {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().tint(.white).controlSize(.large)
                    Text("Removing background…").foregroundStyle(.white)
                    Text("Your photo stays on your device.").font(.footnote).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .preferredColorScheme(.dark)
        .task { await container.purchasesService.refreshSubscriptionStatus() }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidChange)) { notification in
            viewModel.isPremium = notification.userInfo?["hasActiveEntitlement"] as? Bool ?? false
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $viewModel.showingPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { item in
            if let item {
                Task {
                    await viewModel.loadImage(from: item)
                    selectedItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(viewModel: viewModel)
        }
        .alert("Unable to complete", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            viewModel.errorMessage = "A camera is not available on this device. Choose a photo from your library instead."
            return
        }
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var granted = status == .authorized
            if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: .video) }
            if granted { showCamera = true }
            else { viewModel.errorMessage = "Allow camera access for CleanCut in Settings, or choose a photo from your library." }
        }
    }

    private var homeContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CleanCut")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if container.config.featureFlags.paywall && !viewModel.isPremium {
                Button(action: { isShowingPaywall = true }) {
                        Text("PRO")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(cleanCutHex: "#2C7BE5"), in: Capsule())
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                }
                .accessibilityLabel("CleanCut Pro")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Hero
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(cleanCutHex: "#2C7BE5").opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: "scissors")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color(cleanCutHex: "#2C7BE5"))
                }

                VStack(spacing: 8) {
                    Text("Remove Backgrounds")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("People, pets, and products. Processed on your device.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // CTA Buttons
            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Spacer()
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(14)
                }

                Button(action: openCamera) {
                    HStack {
                        Spacer()
                        Image(systemName: "camera")
                        Text("Take a Photo")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
