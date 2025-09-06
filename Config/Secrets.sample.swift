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
    // Supabase
    public static let supabaseURL: URL = URL(string: "https://awlurlliijipymvjkswv.supabase.co")!
    public static let supabaseAnonKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3bHVybGxpaWppcHltdmprc3d2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4MzAyMzAsImV4cCI6MjA3MjQwNjIzMH0.rAApXP7E6NRlmMZIum20TPN-ysgveidw5qS-9aAZUqw"

    // TelemetryDeck (analytics)
    // Use a test app ID here if desired
    public static let telemetryDeckAppID: String = ""
}
#endif
