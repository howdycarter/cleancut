//
//  SignInView.swift
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.container) private var container

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var pendingUser: User?
    @State private var signInAlert: SignInAlert?

    var onSignedIn: (User) -> Void
    @State private var showCreateAccount: Bool = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header with animated logo
            VStack(spacing: 12) {
                // Keep logo static; circle still breathes
                LogoView(size: 120, animateLogo: false)
                Text(container.config.appName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                Text("auth.subtitle")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            // Error banner
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                    .accessibilityLabel(Text("auth.error.access"))
            }

            // Form
            VStack(spacing: DesignTokens.Spacing.md) {
                TextField(LocalizedStringKey("auth.email"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

                SecureField(LocalizedStringKey("auth.password"), text: $password)
                    .textContentType(.password)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

                Button(action: signIn) {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text("auth.signin")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPrimaryEnabled ? DesignTokens.primaryColor : DesignTokens.primaryColor.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                }
                .disabled(!isPrimaryEnabled || isLoading)
                .accessibilityLabel(Text("auth.signin.access"))
            }

            // Or separator
            HStack(spacing: 12) {
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                Text("auth.or").foregroundColor(.secondary)
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
            }

            // Sign in with Apple (visual; backend wired when using Supabase)
            SignInWithAppleButton(.signIn) { _ in
                // No-op in local mode; backend wiring happens in Supabase config.
            } onCompletion: { result in
                // Swallow result; the generator wires the adapter.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .accessibilityLabel(Text("auth.apple.access"))
            .disabled(true)
            .overlay(alignment: .bottomLeading) {
                if container.config.backend == .local {
                    Text("auth.apple.note")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .padding(.leading, 4)
                }
            }

            // Create account link
            NavigationLink(destination: CreateAccountView(onSignedIn: onSignedIn)) {
                Text("auth.createaccount")
                    .font(.footnote)
                    .foregroundColor(DesignTokens.accentColor)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.top, DesignTokens.Spacing.xl)
        .background(
            LinearGradient(colors: [DesignTokens.primaryColor.opacity(0.06), Color.clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle(LocalizedStringKey("auth.nav"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $signInAlert) { kind in
            switch kind {
            case .success:
                return Alert(
                    title: Text("Successfully signed in"),
                    message: nil,
                    dismissButton: .default(Text("OK")) {
                        if let u = pendingUser { onSignedIn(u); pendingUser = nil }
                    }
                )
            case .failure:
                return Alert(
                    title: Text("Failed to sign in"),
                    message: nil,
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

private extension SignInView {
    var isPrimaryEnabled: Bool {
        // Allow any non-empty password for sign-in
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    @MainActor
    func signIn() {
        guard isPrimaryEnabled else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let user = try await container.authRepository.signIn(email: email, password: password)
                isLoading = false
                pendingUser = user
                // Link RevenueCat user and refresh entitlements without prompting App Store login
                await container.purchasesService.logIn(user.id)
                await container.purchasesService.refreshSubscriptionStatus()
                container.analytics.track("Auth.SignInSuccess")
                signInAlert = .success
            } catch {
                isLoading = false
                errorMessage = nil
                container.analytics.track("Auth.SignInFailure")
                signInAlert = .failure
            }
        }
    }
}

private enum SignInAlert: Identifiable {
    case success
    case failure
    var id: Int { hashValue }
}
