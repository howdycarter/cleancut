//
//  DetailView.swift
//

import SwiftUI

struct DetailView: View {
    let itemID: String
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("detail.title")
                .appFont(.title2)
            Text("\(itemID)")
                .appFont(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
    }
}
