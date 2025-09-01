//
//  SettingsViewModel.swift
//

import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var appearanceDark: Bool = false {
        didSet { colorScheme = appearanceDark ? .dark : .light }
    }
    @Published var colorScheme: ColorScheme? = nil
}

