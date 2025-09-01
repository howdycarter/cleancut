//
//  OnboardingCoordinator.swift
//

import SwiftUI

struct OnboardingCoordinator: View {
    let style: OnboardingStyle
    let pages: [OnboardingPage]
    var done: () -> Void

    var body: some View {
        switch style {
        case .carousel:
            CarouselOnboardingView(pages: pages, done: done)
        case .highlights:
            HighlightsOnboardingView(pages: pages, done: done)
        case .minimal:
            MinimalOnboardingView(done: done)
        }
    }
}

