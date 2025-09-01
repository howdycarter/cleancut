//
//  DetailView.swift
//

import SwiftUI

struct DetailView: View {
    let itemID: String
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("detail.title")
                .font(.title2.bold())
            Text("\(itemID)")
                .font(.body.monospaced())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
    }
}
