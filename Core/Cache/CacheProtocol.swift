//
//  CacheProtocol.swift
//
//  Defines the foundational cache abstractions used throughout TheSwiftKit.
//
//  This file provides:
//  - `CacheExpiry`: how long cached data stays valid
//  - `CacheEntry`: a timestamped wrapper around any Codable value
//  - `CacheStorage`: the protocol every cache backend must conform to
//
//  All types are Sendable-compatible so they work safely with Swift concurrency.
//

import Foundation

// MARK: - CacheExpiry

/// Describes how long a cached value remains valid before it must be re-fetched.
///
/// Usage:
/// ```swift
/// cache.set(profile, forKey: "profile_123", expiry: .minutes(15))
/// cache.set(settings, forKey: "app_settings", expiry: .never)
/// ```
public enum CacheExpiry: Sendable, Codable, Equatable {
    /// The value never expires. Use sparingly -- only for truly static data.
    case never
    /// Expires after the given number of seconds.
    case seconds(TimeInterval)
    /// Expires after the given number of minutes.
    case minutes(Double)
    /// Expires after the given number of hours.
    case hours(Double)
    /// Expires after the given number of days.
    case days(Double)

    /// Converts the expiry to a `TimeInterval` (in seconds).
    /// Returns `nil` for `.never`.
    public var timeInterval: TimeInterval? {
        switch self {
        case .never:
            return nil
        case .seconds(let s):
            return s
        case .minutes(let m):
            return m * 60
        case .hours(let h):
            return h * 3600
        case .days(let d):
            return d * 86400
        }
    }
}

// MARK: - CacheEntry

/// An internal wrapper that stores a value alongside its creation date and expiry rule.
/// Both the entry and its contents must be `Codable` so they can be persisted to UserDefaults.
public struct CacheEntry<Value: Codable & Sendable>: Codable, Sendable {
    /// The cached value.
    public let value: Value
    /// When this entry was created.
    public let createdAt: Date
    /// The expiry rule applied to this entry.
    public let expiry: CacheExpiry

    public init(value: Value, expiry: CacheExpiry, createdAt: Date = Date()) {
        self.value = value
        self.createdAt = createdAt
        self.expiry = expiry
    }

    /// Returns `true` when the entry has exceeded its expiry window.
    public var isExpired: Bool {
        guard let interval = expiry.timeInterval else { return false }
        return Date().timeIntervalSince(createdAt) > interval
    }
}

// MARK: - CacheStorage Protocol

/// The contract every cache backend must satisfy.
///
/// Conforming types must be `Sendable` so they can be shared across concurrency domains.
/// The built-in `CacheManager` actor conforms to this protocol.
///
/// **HOW TO BUILD A CUSTOM BACKEND**
/// ```swift
/// actor MyCoreDataCache: CacheStorage {
///     func get<T: Codable & Sendable>(forKey key: String) async -> T? { ... }
///     func set<T: Codable & Sendable>(_ value: T, forKey key: String, expiry: CacheExpiry) async { ... }
///     func remove(forKey key: String) async { ... }
///     func removeAll() async { ... }
///     func invalidate(matching pattern: String) async { ... }
/// }
/// ```
public protocol CacheStorage: Sendable {
    /// Retrieves a previously cached value, or `nil` if the key is missing or expired.
    func get<T: Codable & Sendable>(forKey key: String) async -> T?

    /// Stores a value under the given key with the specified expiry.
    func set<T: Codable & Sendable>(_ value: T, forKey key: String, expiry: CacheExpiry) async

    /// Removes a single cached value.
    func remove(forKey key: String) async

    /// Removes every cached value managed by this storage backend.
    func removeAll() async

    /// Removes all entries whose keys match a simple wildcard pattern.
    ///
    /// Supported patterns:
    /// - `"profile_*"` — matches keys that start with `"profile_"`
    /// - `"*_list"` — matches keys that end with `"_list"`
    /// - `"*settings*"` — matches keys that contain `"settings"`
    /// - `"exact_key"` — matches only the exact key
    func invalidate(matching pattern: String) async
}
