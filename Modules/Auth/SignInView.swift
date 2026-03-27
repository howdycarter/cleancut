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
    @State private var isAppleLoading: Bool = false
    @State private var errorMessage: String?
    @State private var pendingUser: User?
    @State private var signInAlert: SignInAlert?

    /// The raw nonce for the current Apple sign-in attempt.
    /// Generated fresh on each request; the SHA-256 hash is sent to Apple,
    /// and the raw value is sent to Supabase for verification.
    @State private var currentNonce: String?

    var onSignedIn: (User) -> Void
    @State private var showCreateAccount: Bool = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header with animated logo
            VStack(spacing: 12) {
                // Keep logo static; circle still breathes
                LogoView(size: 120, animateLogo: false)
                Text(container.config.appName)
                    .font(AppTypography.custom(size: 32, weight: .bold, relativeTo: .largeTitle))
                    .frame(maxWidth: .infinity)
                Text("auth.subtitle")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            // Error banner
            if let errorMessage {
                Text(errorMessage)
                    .appFont(.footnote)
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
                    .background(DS.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

                SecureField(LocalizedStringKey("auth.password"), text: $password)
                    .textContentType(.password)
                    .padding(12)
                    .background(DS.Colors.surfaceSecondary)
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
                .disabled(!isPrimaryEnabled || isLoading || isAppleLoading)
                .accessibilityLabel(Text("auth.signin.access"))
            }

            // Or separator
            HStack(spacing: 12) {
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                Text("auth.or").foregroundColor(.secondary)
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
            }

            // ------------------------------------------------------------------
            // Sign in with Apple
            //
            // The button is gated behind the `appleSignIn` feature flag.
            // When enabled with a Supabase backend, the full SIWA flow runs:
            //   onRequest  -> generate a fresh nonce, SHA-256 hash it for Apple
            //   onComplete -> extract the identity token, exchange it with Supabase
            //
            // When the backend is `.local`, the mock service returns a fake user.
            // When the flag is off, the button is shown disabled (greyed out).
            // ------------------------------------------------------------------
            if container.config.featureFlags.appleSignIn {
                ZStack {
                    SignInWithAppleButton(.signIn) { request in
                        // Generate a fresh cryptographic nonce for this sign-in attempt.
                        let nonce = AppleSignInService.randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleSignInService.sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignInCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    .accessibilityLabel(Text("auth.apple.access"))
                    .disabled(isLoading || isAppleLoading)

                    // Loading overlay shown while exchanging the token with Supabase.
                    if isAppleLoading {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 44)
                            .overlay(ProgressView().tint(.white))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if container.config.backend == .local {
                        Text("auth.apple.note")
                            .appFont(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .padding(.leading, 4)
                    }
                }
            } else {
                // Feature flag is off: show the button disabled so users see
                // SIWA is supported but not yet configured.
                SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .accessibilityLabel(Text("auth.apple.access"))
                .disabled(true)
            }

            // Create account link
            NavigationLink(destination: CreateAccountView(onSignedIn: onSignedIn)) {
                Text("auth.createaccount")
                    .appFont(.footnote)
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

// MARK: - Actions

private extension SignInView {
    var isPrimaryEnabled: Bool {
        // Allow any non-empty password for sign-in
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    // MARK: Email / Password Sign In

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

    // MARK: Sign in with Apple

    /// Handles the `onCompletion` callback from `SignInWithAppleButton`.
    ///
    /// **Success path:**
    /// 1. Extract the `ASAuthorizationAppleIDCredential` from the authorization.
    /// 2. Read the identity token JWT from the credential.
    /// 3. Pass the token + raw nonce to `AuthRepository.signInWithApple()`.
    /// 4. On success, link RevenueCat, track analytics, and navigate.
    ///
    /// **Edge cases handled:**
    /// - User cancellation (`.canceled` error code) -- silently ignored.
    /// - Missing or invalid identity token -- shows user-friendly error.
    /// - Network / Supabase errors -- shows error banner + failure alert.
    /// - First-time sign-in (Apple sends name + email only once) -- the name/email
    ///   from the credential is available in the completion but Supabase stores them
    ///   in `raw_user_meta_data` automatically on account creation.
    @MainActor
    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // Check if the user simply tapped "Cancel".
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                container.analytics.track("Auth.AppleSignInCancelled")
                return
            }
            errorMessage = error.localizedDescription
            container.analytics.track("Auth.AppleSignInFailure",
                                      properties: ["error": error.localizedDescription])
            signInAlert = .failure

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = NSLocalizedString("auth.apple.error.token", comment: "")
                signInAlert = .failure
                return
            }
            guard let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = NSLocalizedString("auth.apple.error.token", comment: "")
                signInAlert = .failure
                return
            }
            guard let nonce = currentNonce else {
                // This should never happen if onRequest ran correctly.
                errorMessage = NSLocalizedString("auth.apple.error.token", comment: "")
                signInAlert = .failure
                return
            }

            // Exchange the Apple token for a Supabase session asynchronously.
            isAppleLoading = true
            errorMessage = nil
            Task {
                do {
                    let user = try await container.authRepository.signInWithApple(
                        idToken: identityToken,
                        nonce: nonce
                    )

                    isAppleLoading = false
                    pendingUser = user

                    // Link RevenueCat and refresh entitlements.
                    await container.purchasesService.logIn(user.id)
                    await container.purchasesService.refreshSubscriptionStatus()

                    container.analytics.track("Auth.AppleSignInSuccess")
                    signInAlert = .success
                } catch {
                    isAppleLoading = false
                    errorMessage = error.localizedDescription
                    container.analytics.track("Auth.AppleSignInFailure",
                                              properties: ["error": error.localizedDescription])
                    signInAlert = .failure
                }
            }
        }
    }
}

// MARK: - Supporting Types

private enum SignInAlert: Identifiable {
    case success
    case failure
    var id: Int { hashValue }
}
