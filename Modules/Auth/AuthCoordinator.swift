//
//  AuthCoordinator.swift
//

import SwiftUI

struct AuthCoordinator: View {
    var onSignedIn: (User) -> Void
    @Environment(\.container) private var container
    @State private var newUser: User?

    var body: some View {
        NavigationStack {
            SignInView { user in
                Task {
                    // After sign-in, check if profile exists. If not, push setup.
                    await container.purchasesService.logIn(user.id)
                    if let existing = try? await container.profileRepository.fetchProfile(for: user.id), existing != nil {
                        onSignedIn(user)
                    } else {
                        newUser = user
                    }
                }
            }
            .sheet(item: $newUser) { u in
                NavigationStack {
                    ProfileSetupView(user: u) {
                        Task { await container.purchasesService.logIn(u.id) }
                        onSignedIn(u)
                    }
                }
            }
        }
    }
}
