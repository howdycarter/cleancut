//
//  ContainerTests.swift
//

import XCTest
@testable import CleanCut

final class ContainerTests: XCTestCase {
    func testUnconfiguredPurchasesDoNotExposeDemoProducts() async {
        let options = await NoopPurchasesService().loadOfferings(includeAll: true)
        XCTAssertTrue(options.isEmpty)
    }

    func testUnconfiguredPurchaseCannotSucceed() async {
        do {
            try await NoopPurchasesService().purchase(packageIdentifier: "unconfigured")
            XCTFail("An unconfigured purchase must not report success")
        } catch {
            XCTAssertEqual(error as? PurchaseFriendlyError, .unavailable)
        }
    }

    func testUnconfiguredRestoreCannotSucceed() async {
        do {
            try await NoopPurchasesService().restorePurchases()
            XCTFail("An unconfigured restore must not report success")
        } catch {
            XCTAssertEqual(error as? PurchaseFriendlyError, .unavailable)
        }
    }

    func testContainerBuilds() throws {
        let container = DIContainer.makeDefault()
        XCTAssertNotNil(container.userRepository as Any)
        XCTAssertNotNil(container.authRepository as Any)
        XCTAssertEqual(container.config.appName.isEmpty, false)
    }
}

import UIKit

@MainActor
final class ImageEditingTests: XCTestCase {
    private func sampleImage(scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 12), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 12))
        }
    }

    func testTransparentExportPreservesPNGAndPixelDimensions() {
        let image = sampleImage(scale: 2)
        let output = BackgroundRemovalService.shared.compositeOnBackground(image, background: .transparent)
        XCTAssertEqual(output.cgImage?.width, 32)
        XCTAssertEqual(output.cgImage?.height, 24)
        XCTAssertNotNil(output.pngData())
        XCTAssertEqual(output.cgImage?.alphaInfo, image.cgImage?.alphaInfo)
    }

    func testBackgroundCompositionKeepsOriginalResolution() {
        let image = sampleImage(scale: 2)
        let output = BackgroundRemovalService.shared.compositeOnBackground(image, background: .custom, color: .blue)
        XCTAssertEqual(output.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(output.cgImage?.height, image.cgImage?.height)
        XCTAssertNotEqual(output.pngData(), image.pngData())
    }

    func testCameraOrientationIsRenderedIntoPixels() {
        let original = sampleImage()
        let oriented = UIImage(cgImage: original.cgImage!, scale: 1, orientation: .right)
        let normalized = BackgroundRemovalService.normalizedImage(oriented)
        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(normalized.size, oriented.size)
        XCTAssertNotNil(normalized.cgImage)
    }

    func testFullResolutionAndCustomColorsRequirePro() {
        let model = PhotoEditorViewModel()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2048, height: 1024), format: format).image { _ in }
        model.processedImage = ProcessedImage(original: image, processed: image)
        model.updateBackground(.custom)
        XCTAssertEqual(model.processedImage?.background, .transparent)
        XCTAssertEqual(model.composited()?.cgImage?.width, 1024)
        model.isPremium = true
        model.updateBackground(.custom)
        XCTAssertEqual(model.processedImage?.background, .custom)
        XCTAssertEqual(model.composited()?.cgImage?.width, 2048)
    }

    func testCustomColorUpdatesExportAndResetClearsResult() {
        let model = PhotoEditorViewModel()
        let image = sampleImage()
        model.processedImage = ProcessedImage(original: image, processed: image)
        model.isPremium = true
        model.updateBackground(.custom)
        model.updateCustomColor(.blue)
        XCTAssertEqual(model.processedImage?.background, .custom)
        XCTAssertEqual(model.processedImage?.customColor, .blue)
        XCTAssertNotNil(model.composited())
        model.reset()
        XCTAssertNil(model.composited())
    }
}

import StoreKitTest

@MainActor
final class StoreKitPurchaseTests: XCTestCase {
    private func session() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "CleanCut", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    func testStoreKitLoadsLocalizedPlans() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let service = StoreKitPurchasesService(productIdentifiers: Secrets.storeProductIdentifiers)
        let plans = await service.loadOfferings(includeAll: false)
        XCTAssertEqual(Set(plans.map(\.id)), Set(Secrets.storeProductIdentifiers))
        XCTAssertTrue(plans.allSatisfy { !$0.price.isEmpty })
    }

    func testVerifiedPurchaseAndRestoreUnlockPro() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let service = StoreKitPurchasesService(productIdentifiers: Secrets.storeProductIdentifiers)
        try await service.purchase(packageIdentifier: Secrets.storeProductIdentifiers[0])
        XCTAssertTrue(service.hasActiveEntitlement)
        let restoredService = StoreKitPurchasesService(productIdentifiers: Secrets.storeProductIdentifiers)
        try await restoredService.restorePurchases()
        XCTAssertTrue(restoredService.hasActiveEntitlement)
    }

    func testRefundRevokesPro() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let service = StoreKitPurchasesService(productIdentifiers: Secrets.storeProductIdentifiers)
        service.configure()
        defer { service.stopMonitoring() }
        try await service.purchase(packageIdentifier: Secrets.storeProductIdentifiers[0])
        XCTAssertTrue(service.hasActiveEntitlement)
        let transaction = try XCTUnwrap(session.allTransactions().last)
        try session.refundTransaction(identifier: transaction.identifier)
        // StoreKit delivers revocations asynchronously through Transaction.updates.
        for _ in 0..<50 where service.hasActiveEntitlement {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(service.hasActiveEntitlement, "The StoreKit transaction listener must revoke Pro after a refund")
    }

    func testUnknownProductCannotUnlockPro() async throws {
        let session = try session()
        defer { session.clearTransactions() }
        let service = StoreKitPurchasesService(productIdentifiers: Secrets.storeProductIdentifiers)
        do {
            try await service.purchase(packageIdentifier: "not.an.app.product")
            XCTFail("Unknown products must be rejected")
        } catch {
            XCTAssertEqual(error as? PurchaseFriendlyError, .unavailable)
            XCTAssertFalse(service.hasActiveEntitlement)
        }
    }
}
