//
//  AppEvents.swift
//

import Foundation

extension Notification.Name {
    static let authStatusDidChange = Notification.Name("authStatusDidChange")
    static let profileDidChange = Notification.Name("profileDidChange")
    static let subscriptionDidChange = Notification.Name("subscriptionDidChange")
    /// Posted when the user signs out. The caching layer listens for this
    /// notification to automatically clear all cached personal data.
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

// Keys for subscriptionDidChange userInfo payload
public enum SubscriptionEventKey {
    public static let productName = "productName"   // String
    public static let expiresAt = "expiresAt"       // Date
}
