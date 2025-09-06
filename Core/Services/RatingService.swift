//
//  RatingService.swift
//

import Foundation
import SwiftUI
// Pure SwiftUI/URL approach; caller opens URLs via openURL

public enum RatingService {
    /// Builds the App Store write-review URL for a given app id.
    public static func appReviewURL(appId: String) -> URL? {
        // Use itms-apps scheme to jump directly to App Store
        URL(string: "itms-apps://apps.apple.com/app/id\(appId)?action=write-review")
    }

    /// Returns the best review URL (itms-apps if available; otherwise web).
    public static func bestReviewURL(appId: String) -> URL? {
        appReviewURL(appId: appId) ?? URL(string: "https://apps.apple.com/app/id\(appId)?action=write-review")
    }
}
