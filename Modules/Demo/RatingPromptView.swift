//
//  RatingPromptView.swift
//

import SwiftUI

struct RatingPromptView: View {
    @Binding var isPresented: Bool
    var appId: String
    @Environment(\.openURL) private var openURL

    @State private var selected: Int? = nil

    var body: some View {
        VStack(spacing: 16) {
            Text("Liking the app?")
                .appFont(.title3)
            Text("Tap a star to rate on the App Store.")
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        selected = i
                        if let url = RatingService.bestReviewURL(appId: appId) {
                            openURL(url)
                        }
                        isPresented = false
                    } label: {
                        Image(systemName: (selected ?? 0) >= i ? "star.fill" : "star")
                            .font(AppTypography.custom(size: 28, weight: .regular, relativeTo: .title))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Later") { isPresented = false }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }
}
