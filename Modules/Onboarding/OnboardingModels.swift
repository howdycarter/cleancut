//
//  OnboardingModels.swift
//

import SwiftUI

struct OnboardingPage: Identifiable, Hashable {
    let id = UUID()
    let titleKey: String
    let subtitleKey: String
    let systemImage: String
}

extension Array where Element == OnboardingPage {
    static var defaultPages: [OnboardingPage] {
        [
            .init(titleKey: "onb.welcome.title", subtitleKey: "onb.welcome.subtitle", systemImage: "scissors"),
            .init(titleKey: "onb.build.title", subtitleKey: "onb.build.subtitle", systemImage: "iphone.and.arrow.forward"),
            .init(titleKey: "onb.launch.title", subtitleKey: "onb.launch.subtitle", systemImage: "star.fill")
        ]
    }
}

