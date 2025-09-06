//
//  ShowcaseView.swift
//

import SwiftUI

struct ShowcaseView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true

    var body: some View {
        NavigationStack {
            List {
                Section("showcase.overview") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("__APP_NAME__")
                            .font(.title2.bold())
                        Text("showcase.subtitle")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }

                Section("showcase.actions") {
                    Button {
                        router.push(.detail(id: "demo-item"))
                    } label: { Label("showcase.pushdetail", systemImage: "arrow.right.square") }

                    Button {
                        UserDefaults.standard.set(true, forKey: "forceOnboardingOnce")
                        hasSeenOnboarding = false
                    } label: { Label("showcase.showonboarding", systemImage: "sparkles") }

                    Button {
                        router.push(.settings)
                    } label: { Label("showcase.opensettings", systemImage: "gearshape.fill") }

                    NavigationLink {
                        LocalDataDemoView()
                    } label: { Label("Local DB Demo", systemImage: "internaldrive") }
                }

                Section("showcase.theme") {
                    HStack {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .fill(DesignTokens.primaryColor)
                            .frame(width: 44, height: 44)
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .fill(DesignTokens.accentColor)
                            .frame(width: 44, height: 44)
                        Text("showcase.colors")
                    }
                }
            }
            .navigationTitle(Text("showcase.title"))
        }
    }
}
