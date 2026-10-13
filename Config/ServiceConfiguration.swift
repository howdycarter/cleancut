import Foundation

/// Public service identifiers may be supplied through the app's Info.plist.
/// Never embed server credentials or private signing keys in an iOS app.
public enum Secrets {
    private static func value(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static let storeProductIdentifiers = ["com.chriscarterux.cleancut.monthly", "com.chriscarterux.cleancut.yearly"]

    public static let supabaseURL = URL(string: value("SUPABASE_URL")) ?? URL(string: "https://localhost")!
    public static let supabaseAnonKey = value("SUPABASE_ANON_KEY")
    public static let revenueCatAPIKey = value("REVENUECAT_PUBLIC_API_KEY")
    public static let telemetryDeckAppID = value("TELEMETRYDECK_APP_ID")
    public static let accountDeletionURL = URL(string: value("ACCOUNT_DELETION_URL"))
    public static let aiBackendBaseURL = URL(string: value("AI_BACKEND_URL")) ?? URL(string: "https://localhost")!
}
