//
//  PurchaseFriendlyError.swift
//

import Foundation

public enum PurchaseFriendlyError: Error, LocalizedError, Sendable, Equatable {
    case unavailable
    case ownershipConflict
    case cancelled
    case notAllowed
    case network
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Purchases are unavailable right now. Please try again later."
        case .ownershipConflict:
            return "This subscription is already linked to another account. Please sign in with the correct account to continue."
        case .cancelled:
            return NSLocalizedString("Purchase cancelled", comment: "")
        case .notAllowed:
            return NSLocalizedString("Purchases not allowed on this device.", comment: "")
        case .network:
            return NSLocalizedString("Network error. Please try again.", comment: "")
        case .unknown(let msg):
            return msg
        }
    }
}

