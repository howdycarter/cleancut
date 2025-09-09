//
//  Localization.swift
//

import Foundation

public extension String {
    var localized: String { NSLocalizedString(self, comment: self) }
}

// Replace template tokens in localized strings with app-specific values.
public func localizedReplacingAppName(_ key: String, appName: String) -> String {
    let raw = NSLocalizedString(key, comment: key)
    return raw.replacingOccurrences(of: "__APP_NAME__", with: appName)
}
