//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.container) private var container
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("settings.appearance") {
                    Toggle(isOn: $vm.appearanceDark) {
                        Label("settings.darkmode", systemImage: "moon.fill")
                    }
                }

                Section("settings.legal") {
                    Link(destination: container.config.legal.privacyPolicyURL) {
                        Label("settings.privacy", systemImage: "hand.raised")
                    }
                    Link(destination: container.config.legal.termsURL) {
                        Label("settings.terms", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle(Text("settings.title"))
            .preferredColorScheme(vm.colorScheme)
        }
    }
}
