//
//  ContainerTests.swift
//

import XCTest
@testable import CleanCut

final class ContainerTests: XCTestCase {
    func testUnknownEntitlementRefreshPreservesPaidAccess() {
        let failedRefresh = Notification(name: .subscriptionDidChange)
        XCTAssertTrue(PremiumAccess.resolve(current: true, notification: failedRefresh, paywallEnabled: true))
        XCTAssertFalse(PremiumAccess.resolve(current: false, notification: failedRefresh, paywallEnabled: true))
    }

    func testVerifiedRevocationRemovesAccessUnlessPaywallIsDisabled() {
        let revoked = Notification(name: .subscriptionDidChange, userInfo: ["hasActiveEntitlement": false])
        XCTAssertFalse(PremiumAccess.resolve(current: true, notification: revoked, paywallEnabled: true))
        XCTAssertTrue(PremiumAccess.resolve(current: false, notification: revoked, paywallEnabled: false))
    }

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

import Photos

/// These tests exercise the real view-model transitions with controllable async
/// boundaries. They deliberately do not claim to validate Vision or Photos UI.
@MainActor
final class PhotoFlowTests: XCTestCase {
    private func image(width: CGFloat = 16) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 12), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: 12))
        }
    }

    private func setImage(on model: PhotoEditorViewModel, width: CGFloat = 16) {
        let source = image(width: width)
        model.processedImage = ProcessedImage(original: source, processed: source)
    }

    func testLoadingIsBusyBeforeTheLoaderStartsAndNewerImportWins() async throws {
        let oldLoad = SuspendedPhotoOperation<Data?>()
        let model = PhotoEditorViewModel(removeBackground: { $0 })
        let oldTask = model.loadImage { try await oldLoad.run() }
        XCTAssertTrue(model.isProcessing, "Busy state must include the photo download, not just segmentation")
        XCTAssertEqual(model.processingMessage, "Loading photo…")
        await fulfillment(of: [oldLoad.entered], timeout: 2)

        let newerData = try XCTUnwrap(image(width: 32).pngData())
        let newTask = model.loadImage { newerData }
        await newTask.value
        XCTAssertEqual(model.processedImage?.original.size.width, 32)
        XCTAssertFalse(model.isProcessing)

        oldLoad.succeed(try XCTUnwrap(image().pngData()))
        await oldTask.value
        XCTAssertEqual(model.processedImage?.original.size.width, 32)
        XCTAssertNil(model.errorMessage)
    }

    func testOlderDownloadFailureCannotClearNewImportStateOrShowAnAlert() async throws {
        let oldLoad = SuspendedPhotoOperation<Data?>()
        let newLoad = SuspendedPhotoOperation<Data?>()
        let model = PhotoEditorViewModel(removeBackground: { $0 })
        let oldTask = model.loadImage { try await oldLoad.run() }
        await fulfillment(of: [oldLoad.entered], timeout: 2)
        let newTask = model.loadImage { try await newLoad.run() }
        await fulfillment(of: [newLoad.entered], timeout: 2)

        oldLoad.fail(PhotoFlowTestError.failed)
        await oldTask.value
        XCTAssertTrue(model.isProcessing)
        XCTAssertEqual(model.processingMessage, "Loading photo…")
        XCTAssertNil(model.errorMessage)

        newLoad.succeed(try XCTUnwrap(image(width: 32).pngData()))
        await newTask.value
        XCTAssertFalse(model.isProcessing)
        XCTAssertEqual(model.processedImage?.original.size.width, 32)
    }

    func testCancelLoadingNeverStartsSegmentationAndAllowsRetry() async throws {
        let load = SuspendedPhotoOperation<Data?>()
        var removalCount = 0
        let model = PhotoEditorViewModel(removeBackground: { image in
            removalCount += 1
            return image
        })
        let task = model.loadImage { try await load.run() }
        await fulfillment(of: [load.entered], timeout: 2)
        model.cancelProcessing()
        XCTAssertFalse(model.isProcessing)
        load.succeed(try XCTUnwrap(image().pngData()))
        await task.value
        XCTAssertEqual(removalCount, 0)
        XCTAssertNil(model.processedImage)
        XCTAssertNil(model.errorMessage)

        await model.process(image: image()).value
        XCTAssertEqual(removalCount, 1)
        XCTAssertNotNil(model.processedImage)
    }

    func testResetDuringSegmentationIgnoresNonCooperativeCompletion() async {
        let removal = SuspendedPhotoOperation<UIImage>()
        let model = PhotoEditorViewModel(removeBackground: { _ in try await removal.run() })
        let task = model.process(image: image())
        await fulfillment(of: [removal.entered], timeout: 2)
        model.reset()
        XCTAssertFalse(model.isProcessing)
        removal.succeed(image())
        await task.value
        XCTAssertNil(model.processedImage)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.processingMessage, "")
    }

    func testCancelSegmentationSuppressesLateFailure() async {
        let removal = SuspendedPhotoOperation<UIImage>()
        let model = PhotoEditorViewModel(removeBackground: { _ in try await removal.run() })
        let task = model.process(image: image())
        await fulfillment(of: [removal.entered], timeout: 2)
        model.cancelProcessing()
        removal.fail(BackgroundRemovalError.processingUnavailable)
        await task.value
        XCTAssertFalse(model.isProcessing)
        XCTAssertNil(model.processedImage)
        XCTAssertNil(model.errorMessage)
    }

    func testNewCameraPhotoCannotBeReplacedByOlderSegmentation() async {
        let removal = SuspendedPhotoOperation<UIImage>()
        var removalCount = 0
        let model = PhotoEditorViewModel(removeBackground: { source in
            removalCount += 1
            if removalCount == 1 { return try await removal.run() }
            return source
        })
        let oldTask = model.process(image: image())
        await fulfillment(of: [removal.entered], timeout: 2)
        await model.process(image: image(width: 32)).value
        removal.succeed(image())
        await oldTask.value
        XCTAssertEqual(model.processedImage?.original.size.width, 32)
        XCTAssertFalse(model.isProcessing)
    }

    func testInvalidAndMissingDataDoNotStartSegmentation() async {
        var removalCount = 0
        let model = PhotoEditorViewModel(removeBackground: { image in
            removalCount += 1
            return image
        })
        let inputs: [Data?] = [nil, Data("not an image".utf8)]
        for data in inputs {
            await model.loadImage { data }.value
            XCTAssertEqual(model.errorMessage, "Could not load this photo. Please choose another image.")
            XCTAssertFalse(model.isProcessing)
        }
        XCTAssertEqual(removalCount, 0)
    }

    func testDownloadFailureAndRetryClearTheError() async throws {
        let model = PhotoEditorViewModel(removeBackground: { $0 })
        await model.loadImage { throw PhotoFlowTestError.failed }.value
        XCTAssertEqual(model.errorMessage, "Could not download this photo. Check your connection and try again.")
        XCTAssertFalse(model.isProcessing)
        let data = try XCTUnwrap(image().pngData())
        await model.loadImage { data }.value
        XCTAssertNil(model.errorMessage)
        XCTAssertNotNil(model.processedImage)
    }

    func testSegmentationErrorIsShownAndDoesNotLeaveTheOverlayUp() async {
        let model = PhotoEditorViewModel(removeBackground: { _ in throw BackgroundRemovalError.segmentationFailed })
        await model.process(image: image()).value
        XCTAssertEqual(model.errorMessage, BackgroundRemovalError.segmentationFailed.localizedDescription)
        XCTAssertFalse(model.isProcessing)
        XCTAssertNil(model.processedImage)
    }

    func testCancellationErrorIsNotReportedAsDownloadFailure() async {
        let model = PhotoEditorViewModel(removeBackground: { $0 })
        await model.loadImage { throw CancellationError() }.value
        XCTAssertFalse(model.isProcessing)
        XCTAssertNil(model.errorMessage)
    }

    func testSaveDeniedOrRestrictedDoesNotWriteAndOffersShare() async {
        for status in [PHAuthorizationStatus.denied, .restricted] {
            var writes = 0
            let model = PhotoEditorViewModel(requestPhotoAuthorization: { status }, savePNG: { _ in writes += 1 })
            setImage(on: model)
            let saved = await model.saveToPhotos()
            XCTAssertFalse(saved)
            XCTAssertEqual(writes, 0)
            XCTAssertFalse(model.isSaving)
            XCTAssertEqual(model.errorMessage, "Allow CleanCut to add photos in Settings, or use Share to export your image.")
        }
    }

    func testAuthorizedAndLimitedSaveWriteThePreparedPNG() async throws {
        for status in [PHAuthorizationStatus.authorized, .limited] {
            var savedData: Data?
            let model = PhotoEditorViewModel(requestPhotoAuthorization: { status }, savePNG: { savedData = $0 })
            setImage(on: model)
            let expected = try XCTUnwrap(model.prepareExport()?.data)
            let saved = await model.saveToPhotos()
            XCTAssertTrue(saved)
            XCTAssertEqual(savedData, expected)
            XCTAssertEqual(savedData?.prefix(8), Data([137, 80, 78, 71, 13, 10, 26, 10]))
            XCTAssertFalse(model.isSaving)
            XCTAssertNil(model.errorMessage)
        }
    }

    func testSaveFailureCanBeRetriedWithoutStaleError() async {
        var writes = 0
        let model = PhotoEditorViewModel(requestPhotoAuthorization: { .authorized }, savePNG: { _ in
            writes += 1
            if writes == 1 { throw PhotoFlowTestError.failed }
        })
        setImage(on: model)
        let firstSave = await model.saveToPhotos()
        XCTAssertFalse(firstSave)
        XCTAssertFalse(model.isSaving)
        XCTAssertEqual(model.errorMessage, "Could not save your image. Please try again or use Share.")
        let retry = await model.saveToPhotos()
        XCTAssertTrue(retry)
        XCTAssertEqual(writes, 2)
        XCTAssertNil(model.errorMessage)
    }

    func testRepeatedSaveCannotCreateDuplicateWrites() async {
        let write = SuspendedPhotoOperation<Void>()
        var writes = 0
        var authorizations = 0
        let model = PhotoEditorViewModel(requestPhotoAuthorization: {
            authorizations += 1
            return .authorized
        }, savePNG: { _ in
            writes += 1
            try await write.run()
        })
        setImage(on: model)
        let firstSave = Task { await model.saveToPhotos() }
        await fulfillment(of: [write.entered], timeout: 2)
        XCTAssertTrue(model.isSaving)
        let duplicate = await model.saveToPhotos()
        XCTAssertFalse(duplicate)
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(authorizations, 1)
        write.succeed(())
        let saved = await firstSave.value
        XCTAssertTrue(saved)
        XCTAssertFalse(model.isSaving)
    }

    func testResetWhileAuthorizingPreventsSavingAnOldPhoto() async {
        let authorization = SuspendedPhotoOperation<PHAuthorizationStatus>()
        var writes = 0
        let model = PhotoEditorViewModel(requestPhotoAuthorization: {
            (try? await authorization.run()) ?? .denied
        }, savePNG: { _ in writes += 1 })
        setImage(on: model)
        let task = Task { await model.saveToPhotos() }
        await fulfillment(of: [authorization.entered], timeout: 2)
        model.reset()
        setImage(on: model, width: 32)
        authorization.succeed(.authorized)
        let saved = await task.value
        XCTAssertFalse(saved)
        XCTAssertEqual(writes, 0)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSaving)
    }

    func testCancelledSaveWhileAuthorizingDoesNotWrite() async {
        let authorization = SuspendedPhotoOperation<PHAuthorizationStatus>()
        var writes = 0
        let model = PhotoEditorViewModel(requestPhotoAuthorization: {
            (try? await authorization.run()) ?? .denied
        }, savePNG: { _ in writes += 1 })
        setImage(on: model)
        let task = Task { await model.saveToPhotos() }
        await fulfillment(of: [authorization.entered], timeout: 2)
        task.cancel()
        authorization.succeed(.authorized)
        let saved = await task.value
        XCTAssertFalse(saved)
        XCTAssertEqual(writes, 0)
        XCTAssertFalse(model.isSaving)
        XCTAssertNil(model.errorMessage)
    }

    func testLateSaveFailureCannotShowAnErrorForANewerPhoto() async {
        let write = SuspendedPhotoOperation<Void>()
        let model = PhotoEditorViewModel(requestPhotoAuthorization: { .authorized }, savePNG: { _ in
            try await write.run()
        })
        setImage(on: model)
        let task = Task { await model.saveToPhotos() }
        await fulfillment(of: [write.entered], timeout: 2)
        model.reset()
        setImage(on: model, width: 32)
        write.fail(PhotoFlowTestError.failed)
        let saved = await task.value
        XCTAssertFalse(saved)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSaving)
    }

    func testMissingImageAndEncodingFailureAreActionableAndNeverAskPermission() async {
        var authorizations = 0
        let model = PhotoEditorViewModel(requestPhotoAuthorization: {
            authorizations += 1
            return .authorized
        }, encodePNG: { _ in nil })
        let missingImage = await model.saveToPhotos()
        XCTAssertFalse(missingImage)
        XCTAssertEqual(model.errorMessage, "Choose a photo before exporting.")
        setImage(on: model)
        XCTAssertNil(model.prepareExport())
        let encodingFailed = await model.saveToPhotos()
        XCTAssertFalse(encodingFailed)
        XCTAssertEqual(model.errorMessage, "Could not prepare your PNG. Please try again or choose another photo.")
        XCTAssertEqual(authorizations, 0)
    }

    func testPreparedPNGUsesFreePixelLimitAndProOriginalResolution() throws {
        let model = PhotoEditorViewModel()
        setImage(on: model, width: 2_048)
        let freePNG = try XCTUnwrap(model.prepareExport())
        XCTAssertEqual(UIImage(data: freePNG.data)?.cgImage?.width, 1_024)
        model.isPremium = true
        let proPNG = try XCTUnwrap(model.prepareExport())
        XCTAssertEqual(UIImage(data: proPNG.data)?.cgImage?.width, 2_048)
    }
}

private enum PhotoFlowTestError: Error { case failed }

/// A deliberately non-cooperative dependency: cancelling the caller does not
/// finish this continuation. This reproduces late system-library completions.
@MainActor
private final class SuspendedPhotoOperation<Value> {
    let entered = XCTestExpectation(description: "Async dependency entered")
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?

    func run() async throws -> Value {
        entered.fulfill()
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed(_ value: Value) { finish(.success(value)) }
    func fail(_ error: Error) { finish(.failure(error)) }

    private func finish(_ result: Result<Value, Error>) {
        // Buffer an early response so an expectation timeout cannot strand a task.
        self.result = result
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
