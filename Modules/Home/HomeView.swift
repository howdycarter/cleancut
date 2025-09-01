//
//  HomeView.swift
//

import SwiftUI

struct HomeView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @StateObject private var vm = HomeViewModel()
    @State private var isShowingShowcase: Bool = false

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: 2) }

    var body: some View {
        Group {
            if vm.isGrid {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.md) {
                        ForEach(vm.items) { item in
                            HomeCell(item: item)
                                .onTapGesture { router.push(.detail(id: item.id)) }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            } else {
                List(vm.items) { item in
                    HomeCell(item: item)
                        .onTapGesture { router.push(.detail(id: item.id)) }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { vm.load(layout: container.config.layout) }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("home.showcase") { isShowingShowcase = true }
            }
        }
        .sheet(isPresented: $isShowingShowcase) { ShowcaseView() }
    }
}

private struct HomeCell: View {
    let item: HomeViewModel.Item
    var body: some View {
        Text(item.title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.primaryColor.opacity(0.08))
            .foregroundColor(DesignTokens.primaryColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .accessibilityLabel(Text("home.item.access"))
    }
}
