//
//  TheSwiftKitApp.swift
//

import SwiftUI

@main
struct TheSwiftKitApp: App {
    @StateObject private var router = AppRouter()
    private let container = DIContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView()
                .inject(container)
                .environmentObject(router)
                .appTheme(AppTheme())
        }
    }
}

