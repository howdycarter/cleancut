//
//  CacheConfig.swift
//
//  Centralized, easily extensible default expiry times for every data category.
//
//  Buyers can adjust these values in one place to change caching behaviour across
//  the entire app, or add new categories for their own features.
//
//  Example — adding a cache duration for a custom "Posts" feature:
//  ```swift
//  extension CacheConfig {
//      static let posts       = CacheExpiry.minutes(10)
//      static let postDetail  = CacheExpiry.hours(1)
//  }
//  ```

import Foundation

/// Default cache expiry durations grouped by data category.
///
/// Each static property returns a `CacheExpiry` value that can be passed to
/// `CacheManager.set(_:forKey:expiry:)`.
///
/// The values chosen here are sensible defaults:
/// - Profile data rarely changes and can be cached for a while.
/// - Subscription status should refresh more frequently.
/// - Feature flags and app settings can be long-lived.
///
/// Override any value by shadowing it in an extension in your own file, or
/// simply pass a different `CacheExpiry` when calling `set`.
public enum CacheConfig {

    // MARK: - Profile

    /// How long a user profile is considered fresh after being fetched.
    public static let profileExpiry: CacheExpiry = .hours(1)

    // MARK: - Subscription

    /// How long subscription status is cached before re-checking with the backend.
    /// Kept short so entitlement changes surface quickly.
    public static let subscriptionExpiry: CacheExpiry = .minutes(30)

    // MARK: - App Settings / Feature Flags

    /// How long app-level settings or remote feature flags stay cached.
    public static let settingsExpiry: CacheExpiry = .days(1)

    // MARK: - Generic Defaults

    /// A convenient "short" duration for data that changes frequently.
    public static let shortExpiry: CacheExpiry = .minutes(5)

    /// A convenient "medium" duration for moderately volatile data.
    public static let mediumExpiry: CacheExpiry = .minutes(30)

    /// A convenient "long" duration for rarely changing data.
    public static let longExpiry: CacheExpiry = .hours(6)

    // MARK: - UserDefaults Suite

    /// The UserDefaults suite name used by CacheManager for persistence.
    /// Using a dedicated suite keeps cache data separate from other app preferences.
    public static let userDefaultsSuiteName: String = "com.theswiftkit.cache"

    // MARK: - Key Prefix

    /// All keys written to UserDefaults are prefixed with this string to
    /// avoid collisions with other data stored in the same suite.
    public static let keyPrefix: String = "tsk_cache_"
}
