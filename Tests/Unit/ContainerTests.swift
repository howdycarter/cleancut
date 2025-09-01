//
//  ContainerTests.swift
//

import XCTest
@testable import TheSwiftKit

final class ContainerTests: XCTestCase {
    func testContainerBuilds() throws {
        let container = DIContainer.makeDefault()
        XCTAssertNotNil(container.userRepository as Any)
        XCTAssertNotNil(container.authRepository as Any)
        XCTAssertEqual(container.config.appName.isEmpty, false)
    }
}
