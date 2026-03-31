//
//  HomeView.swift
//  CleanCut
//

import SwiftUI
import PhotosUI

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
                EditorView(processedImage: result, viewModel: viewModel)
            } else {
                homeContent
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $viewModel.showingPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { item in
            if let item {
                Task { await viewModel.loadImage(from: item) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
                Button(action: { isShowingPaywall = true }) {
                    if !viewModel.isPremium {
                        Text("PRO")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#2C7BE5"), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Hero
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#2C7BE5").opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: "scissors")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color(hex: "#2C7BE5"))
                }

                VStack(spacing: 8) {
                    Text("Remove Backgrounds")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("AI-powered • On-device • Instant")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
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

                Button(action: { showCamera = true }) {
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
