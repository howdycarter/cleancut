//
//  AppEvents.swift
//

import Foundation

extension Notification.Name {
    static let authStatusDidChange = Notification.Name("authStatusDidChange")
    static let profileDidChange = Notification.Name("profileDidChange")
    static let subscriptionDidChange = Notification.Name("subscriptionDidChange")
}

// Keys for subscriptionDidChange userInfo payload
public enum SubscriptionEventKey {
    public static let productName = "productName"   // String
    public static let expiresAt = "expiresAt"       // Date
}
