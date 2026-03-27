//
//  SupabaseAuthRepository.swift
//

import Foundation

#if canImport(Supabase)
import Supabase

/// Supabase-backed implementation of AuthRepository.
/// Uses Secrets.supabaseURL and Secrets.supabaseAnonKey for configuration.
/// This actor is Sendable by design and safe for concurrent use.
actor SupabaseAuthRepository: AuthRepository {
    private let client: SupabaseClient

    init(url: URL = Secrets.supabaseURL, key: String = Secrets.supabaseAnonKey) {
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    func signIn(email: String, password: String) async throws -> User {
        // Perform sign-in then query the current user to map into our domain model.
        _ = try await client.auth.signIn(email: email, password: password)
        let u = try await client.auth.user()
        return User(id: u.id.uuidString, email: u.email ?? email)
    }

    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        let response = try await client.auth.signUp(email: email, password: password)
        // If email confirmation is required, session will likely be nil.
        if response.session != nil {
            let u = response.user
            return .signedIn(User(id: u.id.uuidString, email: u.email ?? email))
        } else {
            return .confirmationEmailSent
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        // Exchange the Apple identity token for a Supabase session.
        // Supabase verifies the token with Apple and either signs in an existing user
        // or creates a new account automatically.
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let u = session.user
        return User(id: u.id.uuidString, email: u.email ?? "")
    }

    func signOut() async {
        do { try await client.auth.signOut() } catch { /* no-op for UI */ }
    }

    func currentUser() async -> User? {
        guard let u = try? await client.auth.user() else { return nil }
        return User(id: u.id.uuidString, email: u.email ?? "")
    }
}

#else

// Fallback when Supabase SDK is not linked.
// This keeps the project compiling even without the package.
struct SupabaseAuthRepositoryUnavailable: AuthRepository {
    func signIn(email: String, password: String) async throws -> User {
        throw NSError(domain: "AuthRepository", code: 501, userInfo: [NSLocalizedDescriptionKey: "Supabase SDK not available in this build."])
    }
    func signUp(email: String, password: String) async throws -> SignUpOutcome {
        throw NSError(domain: "AuthRepository", code: 501, userInfo: [NSLocalizedDescriptionKey: "Supabase SDK not available in this build."])
    }
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        throw NSError(domain: "AuthRepository", code: 501, userInfo: [NSLocalizedDescriptionKey: "Supabase SDK not available in this build."])
    }
    func signOut() async {}
    func currentUser() async -> User? { nil }
}

#endif
