//
//  CreateAccountView.swift
//

import SwiftUI

struct CreateAccountView: View {
    @Environment(\.container) private var container

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var onSignedIn: (User) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            VStack(spacing: 8) {
                Text("auth.create.title")
                    .appFont(.largeTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("auth.create.subtitle")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let infoMessage {
                Text(infoMessage)
                    .appFont(.footnote)
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
            }

            if let errorMessage {
                Text(errorMessage)
                    .appFont(.footnote)
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
            }

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
                    .textContentType(.newPassword)
                    .padding(12)
                    .background(DS.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

                SecureField(LocalizedStringKey("auth.password.confirm"), text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding(12)
                    .background(DS.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

                Button(action: signUp) {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text("auth.signup")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPrimaryEnabled ? DesignTokens.primaryColor : DesignTokens.primaryColor.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                }
                .disabled(!isPrimaryEnabled || isLoading)
                .accessibilityLabel(Text("auth.signup.access"))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.top, DesignTokens.Spacing.xl)
        .navigationTitle(LocalizedStringKey("auth.create.nav"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension CreateAccountView {
    var isPrimaryEnabled: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // Enable when email + password are valid; confirm is optional but must match if provided
        return !trimmed.isEmpty && password.count >= 6 && (confirmPassword.isEmpty || password == confirmPassword)
    }

    @MainActor
    func signUp() {
        guard isPrimaryEnabled else { return }
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        Task {
            do {
                let outcome = try await container.authRepository.signUp(email: email, password: password)
                isLoading = false
                switch outcome {
                case .signedIn(let user):
                    onSignedIn(user)
                case .confirmationEmailSent:
                    infoMessage = NSLocalizedString("auth.confirm.email", comment: "")
                }
            } catch {
                isLoading = false
                errorMessage = NSLocalizedString("auth.error.signup", comment: "")
            }
        }
    }
}
