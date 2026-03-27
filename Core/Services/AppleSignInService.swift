//
//  AppleSignInService.swift
//  TheSwiftKit
//
//  ============================================================================
//  SIGN IN WITH APPLE  --  SETUP GUIDE
//  ============================================================================
//
//  This service handles the full "Sign in with Apple" (SIWA) flow and passes
//  the resulting identity token to Supabase for server-side verification.
//
//  Before SIWA will work you need to complete **three** configuration steps:
//
//  ---- 1. Xcode Capability ---------------------------------------------------
//
//  1. Open your .xcodeproj in Xcode.
//  2. Select the app target -> "Signing & Capabilities".
//  3. Click "+ Capability" and add "Sign in with Apple".
//     This adds the `com.apple.developer.applesignin` entitlement automatically.
//
//  ---- 2. Apple Developer Portal ---------------------------------------------
//
//  A) **App ID** (Certificates, Identifiers & Profiles -> Identifiers)
//     - Select your App ID (or create one with your bundle identifier).
//     - Under "Capabilities", check "Sign in with Apple".
//     - Save. Regenerate your provisioning profiles if prompted.
//
//  B) **Service ID** (only needed for web / Supabase redirect flows)
//     - Create a new "Services ID" with an identifier like `com.yourcompany.app.web`.
//     - Enable "Sign in with Apple" and click Configure.
//     - Add your Supabase callback URL as a Return URL:
//         https://<YOUR-PROJECT>.supabase.co/auth/v1/callback
//     - Save. Note the Service ID identifier; you will enter it in Supabase.
//
//  C) **Key** (optional; only if you need server-to-server token refresh)
//     - Create a new Key, enable "Sign in with Apple", and download the .p8 file.
//     - Note the Key ID and your Team ID; Supabase needs both plus the private key.
//
//  ---- 3. Supabase Dashboard -------------------------------------------------
//
//  1. Go to Authentication -> Providers -> Apple.
//  2. Toggle "Apple" ON.
//  3. For **native iOS** sign-in the default settings work out of the box
//     (Supabase validates the Apple JWT directly using Apple's public keys).
//  4. If you also need a web redirect flow, fill in:
//       - Secret Key:  the contents of your .p8 file
//       - Key ID:      from the Apple Developer Portal
//       - Team ID:     your Apple Developer Team ID
//       - Service ID:  the Services ID identifier from step 2-B
//  5. Save.
//
//  ---- 4. Secrets.swift ------------------------------------------------------
//
//  The native iOS flow does NOT require any secrets beyond Supabase URL + anon
//  key (which you already have).  The Apple-specific keys in Secrets.swift are
//  only needed if you configure a web/redirect flow.
//
//  ---- 5. Feature Flag -------------------------------------------------------
//
//  Set `featureFlags.appleSignIn = true` in your AppConfig to show the button.
//
//  ============================================================================

import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Apple Sign-In Error

/// Domain-specific errors for the Sign in with Apple flow.
/// Each case carries a user-friendly message suitable for display in an alert.
public enum AppleSignInError: LocalizedError, Sendable {
    /// The user dismissed the Apple sign-in sheet.
    case cancelled
    /// Apple did not return the expected identity token JWT.
    case missingIdentityToken
    /// The identity token data could not be decoded to a UTF-8 string.
    case invalidIdentityToken
    /// A network or server error occurred during the Apple authorization.
    case authorizationFailed(String)
    /// The Supabase token exchange failed.
    case backendError(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return NSLocalizedString("auth.apple.error.cancelled", comment: "")
        case .missingIdentityToken:
            return NSLocalizedString("auth.apple.error.token", comment: "")
        case .invalidIdentityToken:
            return NSLocalizedString("auth.apple.error.token", comment: "")
        case .authorizationFailed(let detail):
            return String(format: NSLocalizedString("auth.apple.error.authorization", comment: ""), detail)
        case .backendError(let detail):
            return String(format: NSLocalizedString("auth.apple.error.backend", comment: ""), detail)
        }
    }
}

// MARK: - Apple Sign-In Result

/// The raw output from a successful Apple authorization, before passing to Supabase.
public struct AppleSignInResult: Sendable {
    /// The raw (unhashed) nonce. Pass this to Supabase.
    public let rawNonce: String
    /// The Apple identity token JWT as a string. Pass this to Supabase.
    public let identityToken: String
    /// The user's full name (only provided on the *first* authorization; nil on subsequent sign-ins).
    public let fullName: PersonNameComponents?
    /// The user's email (only provided on the *first* authorization; nil on subsequent sign-ins).
    public let email: String?
}

// MARK: - Apple Sign-In Service Protocol

/// Protocol for the Apple Sign-In service, enabling dependency injection and testability.
/// Conform to `Sendable` to match the project-wide concurrency safety pattern.
public protocol AppleSignInServiceProtocol: Sendable {
    /// Triggers the native Apple sign-in sheet and returns the authorization result.
    /// This method handles nonce generation, the ASAuthorization request, and token extraction.
    /// - Throws: `AppleSignInError` on failure or cancellation.
    @MainActor
    func authorize() async throws -> AppleSignInResult
}

// MARK: - Live Implementation

/// Production implementation that presents the native Apple sign-in sheet using
/// `AuthenticationServices`. Safe to call from any `@MainActor` context.
///
/// **Flow:**
/// 1. Generate a cryptographically random nonce.
/// 2. SHA-256 hash the nonce and attach it to the Apple authorization request.
/// 3. Present the system sign-in sheet via `ASAuthorizationController`.
/// 4. Extract the identity token JWT from the credential.
/// 5. Return the token + raw nonce so the caller can pass them to Supabase.
public final class AppleSignInService: NSObject, AppleSignInServiceProtocol, Sendable {

    public override init() {
        super.init()
    }

    @MainActor
    public func authorize() async throws -> AppleSignInResult {
        // 1. Generate a random nonce for this sign-in attempt.
        let rawNonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(rawNonce)

        // 2. Build the Apple ID authorization request.
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        // 3. Perform the authorization using the async helper.
        let credential = try await performAuthorization(request: request)

        // 4. Extract the identity token.
        guard let tokenData = credential.identityToken else {
            throw AppleSignInError.missingIdentityToken
        }
        guard let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.invalidIdentityToken
        }

        // 5. Return the result. The caller is responsible for passing idToken + rawNonce
        //    to `AuthRepository.signInWithApple(idToken:nonce:)`.
        return AppleSignInResult(
            rawNonce: rawNonce,
            identityToken: identityToken,
            fullName: credential.fullName,
            email: credential.email
        )
    }

    // MARK: - ASAuthorization Async Bridge

    /// Bridges the delegate-based `ASAuthorizationController` into Swift concurrency.
    @MainActor
    private func performAuthorization(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AuthorizationDelegate(continuation: continuation)
            // Retain the delegate for the lifetime of the request.
            objc_setAssociatedObject(controller, &Self.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.delegate = delegate
            controller.performRequests()
        }
    }

    private static var delegateKey: UInt8 = 0

    // MARK: - Nonce Utilities

    /// Generates a cryptographically random string suitable for use as a nonce.
    /// The raw nonce is sent to Supabase; the SHA-256 hash is sent to Apple.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Fallback: should never happen on iOS, but be defensive.
            randomBytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    /// Returns the SHA-256 hash of the input string, encoded as a lowercase hex string.
    /// Apple requires the nonce to be hashed before it is attached to the authorization request.
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate (Async Bridge)

/// A private delegate class that bridges `ASAuthorizationControllerDelegate` callbacks
/// into a `CheckedContinuation`. Each instance is used for exactly one authorization request.
private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, @unchecked Sendable {
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    private var hasResumed = false

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !hasResumed else { return }
        hasResumed = true
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: AppleSignInError.missingIdentityToken)
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation.resume(throwing: AppleSignInError.cancelled)
        } else {
            continuation.resume(throwing: AppleSignInError.authorizationFailed(error.localizedDescription))
        }
    }
}

// MARK: - Mock Implementation (for local/preview use)

/// A no-op implementation used when the backend is set to `.local` or during SwiftUI previews.
/// Always throws `.cancelled` to simulate a dismissed sheet, keeping the UI responsive.
public struct MockAppleSignInService: AppleSignInServiceProtocol {
    public init() {}

    @MainActor
    public func authorize() async throws -> AppleSignInResult {
        // In local mode there is no real Apple sign-in; return a mock result.
        return AppleSignInResult(
            rawNonce: "mock-nonce",
            identityToken: "mock-identity-token",
            fullName: PersonNameComponents(givenName: "Test", familyName: "User"),
            email: "test@local.example"
        )
    }
}
