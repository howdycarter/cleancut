//
//  TestDriveView.swift
//

import SwiftUI

struct TestDriveView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true
    @AppStorage("forceOnboardingOnce") private var forceOnboardingOnce: Bool = false

    @State private var showAuth: Bool = false
    @State private var showRating: Bool = false
    var continueAction: (AppRoute?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("tester.overview") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(container.config.appName)
                            .font(.title2.bold())
                        Text("tester.subtitle")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }

                Section("tester.section.flow") {
                    Button { continueAction(nil) } label: {
                        Label("tester.launchapp", systemImage: "play.fill")
                    }
                    Button { hasSeenOnboarding = false } label: {
                        Label("tester.resetonboarding", systemImage: "arrow.counterclockwise")
                    }
                    Button { forceOnboardingOnce = true; hasSeenOnboarding = false; continueAction(nil) } label: {
                        Label("tester.showonboarding", systemImage: "sparkles")
                    }
                    Button { showAuth = true } label: {
                        Label("tester.showauth", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    Button {
                        Task {
                            // Sign out to force auth, then run full flow: onboarding -> auth -> app (paywall removed)
                            await container.authRepository.signOut()
                            await container.purchasesService.logOut()
                            NotificationCenter.default.post(name: .authStatusDidChange, object: nil)
                            UserDefaults.standard.set(true, forKey: "forceOnboardingOnce")
                            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                            continueAction(nil)
                        }
                    } label: {
                        Label("tester.runfullflow", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("tester.section.shortcuts") {
                    Button { continueAction(.home) } label: {
                        Label("tester.openhome", systemImage: "house.fill")
                    }
                    Button { continueAction(.settings) } label: {
                        Label("tester.opensettings", systemImage: "gearshape.fill")
                    }
                    Button { continueAction(.notifications) } label: {
                        Label("tester.opennotifs", systemImage: "bell.badge.fill")
                    }
                    Button { continueAction(.paywall) } label: {
                        Label("Open Paywall", systemImage: "sparkles")
                    }
                    NavigationLink {
                        LocalDataDemoView()
                    } label: { Label("Local DB Demo", systemImage: "internaldrive") }
                    
                    Button { showRating = true } label: {
                        Label("Show Rating Prompt", systemImage: "star.fill")
                    }
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
            .navigationTitle(Text("tester.title"))
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthCoordinator { _ in showAuth = false }
        }
        .sheet(isPresented: $showRating) {
            // Using TestFlight app id for demo. Replace with your own.
            RatingPromptView(isPresented: $showRating, appId: "899247664")
                .presentationDetents([.medium])
        }
        .animation(.easeInOut(duration: 0.25), value: showAuth)
        .animation(.easeInOut(duration: 0.25), value: showRating)
    }
}
