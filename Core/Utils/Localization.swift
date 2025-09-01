//
//  Localization.swift
//

import Foundation

public extension String {
    var localized: String { NSLocalizedString(self, comment: self) }
}

