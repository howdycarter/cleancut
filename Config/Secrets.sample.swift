//
//  Secrets.sample.swift
//  Duplicate to Secrets.swift and fill in values.
//

import Foundation

// This sample is a template and should not compile into the app by default.
// If you want to build using the sample values, add `USE_SAMPLE_SECRETS` to
// your target's Swift Compiler - Custom Flags (Other Swift Flags): `-D USE_SAMPLE_SECRETS`.
#if USE_SAMPLE_SECRETS
public enum Secrets {
    // Supabase (required for Supabase backend)
    public static let supabaseURL: URL = URL(string: "https://YOUR-PROJECT.supabase.co")!
    public static let supabaseAnonKey: String = "YOUR_SUPABASE_ANON_KEY"

    // Sign in with Apple
    // NOTE: The native iOS SIWA flow does NOT require these secrets. Supabase validates
    // Apple JWTs using Apple's public keys automatically. These values are only needed
    // if you configure a **web-based** Apple sign-in redirect flow in Supabase.
    // See AppleSignInService.swift for the full setup guide.
    public static let appleServiceId: String = "" // e.g., com.example.web (Services ID, not App ID)
    public static let appleTeamId: String = ""    // Your 10-character Apple Team ID
    public static let appleKeyId: String = ""     // Key ID from the Apple Developer Portal
    public static let applePrivateKeyPEM: String = "" // Contents of the .p8 key file (PKCS8 PEM)

    // Optional: Account deletion HTTPS endpoint
    public static let accountDeletionURLString: String = ""
    public static var accountDeletionURL: URL? { URL(string: accountDeletionURLString) }

    // TelemetryDeck (analytics)
    public static let telemetryDeckAppID: String = ""

    // RevenueCat (public API key to enable paywall)
    public static let revenueCatAPIKey: String = ""

    // AI Backend base URL (Flask). For local dev: http://127.0.0.1:5001
    public static let aiBackendBaseURLString: String = "http://127.0.0.1:5001"
    public static var aiBackendBaseURL: URL { URL(string: aiBackendBaseURLString)! }
}
#endif
