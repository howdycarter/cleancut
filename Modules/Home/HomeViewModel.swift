//
//  HomeViewModel.swift
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    struct Item: Identifiable, Hashable { let id: String; let title: String }
    @Published var items: [Item] = []
    @Published var isGrid: Bool = false

    func load(layout: LayoutStyle) {
        isGrid = layout == .grid
        items = (1...20).map { .init(id: "item-\($0)", title: "Item \($0)") }
    }
}

