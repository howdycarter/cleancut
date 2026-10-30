import XCTest
import UIKit
import SwiftUI
import Vision
import Photos
@testable import CleanCut

/// Real Apple-framework integration tests. No segmentation, Photos writer, or
/// share controller is substituted. Attachments preserve the generated fixture
/// and output. A missing Vision model is a failed acceptance gate, never a pass.
@MainActor
final class RuntimeAcceptanceTests: XCTestCase {
    /// Original synthetic artwork, generated entirely by this test: a blue
    /// bottle with a red cap on a pale yellow background. No external assets.
    private func bottle() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 480, height: 640), format: format).image { context in
            UIColor(red: 0.98, green: 0.91, blue: 0.69, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 480, height: 640))
            UIColor(white: 0.1, alpha: 0.12).setFill()
            UIBezierPath(ovalIn: CGRect(x: 120, y: 551, width: 260, height: 35)).fill()
            let body = UIBezierPath(roundedRect: CGRect(x: 154, y: 195, width: 172, height: 365), cornerRadius: 38)
            UIColor(red: 0.03, green: 0.28, blue: 0.67, alpha: 1).setFill()
            body.fill()
            UIColor(red: 0.05, green: 0.38, blue: 0.8, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 195, y: 115, width: 90, height: 130), cornerRadius: 20).fill()
            UIColor(red: 0.8, green: 0.08, blue: 0.06, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 188, y: 96, width: 104, height: 54), cornerRadius: 10).fill()
            UIColor.white.withAlphaComponent(0.25).setFill()
            UIBezierPath(roundedRect: CGRect(x: 171, y: 230, width: 22, height: 264), cornerRadius: 11).fill()
            UIColor.white.setFill()
            context.fill(CGRect(x: 195, y: 330, width: 90, height: 100))
            let text = "H₂O" as NSString
            text.draw(at: CGPoint(x: 207, y: 359), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28), .foregroundColor: UIColor.systemBlue])
        }
    }

    private func attach(_ image: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func rgba(_ image: UIImage) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let cg = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return (pixels, cg.width, cg.height)
    }

    func testRealVisionForegroundMaskAndOrientation() async throws {
        guard ProcessInfo.processInfo.environment["CLEANCUT_VISION_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Real Vision release gate requires explicit CLEANCUT_VISION_ACCEPTANCE=1 on a capable runtime/device; skipping does not clear acceptance")
        }
        let source = bottle()
        attach(source, "original-synthetic-bottle-480x640")
        // Probe directly first to retain the framework's exact error, which the
        // production service intentionally replaces with a friendly message.
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try VNImageRequestHandler(cgImage: try XCTUnwrap(source.cgImage), options: [:]).perform([request])
        } catch {
            let evidence = XCTAttachment(string: String(reflecting: error as NSError))
            evidence.name = "Vision-runtime-error"
            evidence.lifetime = .keepAlways
            add(evidence)
            let cpuRequest = VNGenerateForegroundInstanceMaskRequest()
            cpuRequest.usesCPUOnly = true
            do {
                try VNImageRequestHandler(cgImage: try XCTUnwrap(source.cgImage), options: [:]).perform([cpuRequest])
                print("CLEANCUT_CPU_PROBE: request succeeded; instances=\(cpuRequest.results?.first?.allInstances.count ?? 0)")
            } catch {
                print("CLEANCUT_CPU_PROBE: \(error as NSError)")
            }
            XCTFail("Real Vision inference unavailable: \(error as NSError)")
            return
        }
        XCTAssertFalse(try XCTUnwrap(request.results?.first).allInstances.isEmpty, "Synthetic bottle must be recognized before accepting the fixture")
        let result = try await BackgroundRemovalService.shared.removeBackground(from: source)
        attach(result, "real-Vision-transparent-output")
        let output = try rgba(result)
        XCTAssertEqual(output.width, 480)
        XCTAssertEqual(output.height, 640)
        let alphas = stride(from: 3, to: output.pixels.count, by: 4).map { output.pixels[$0] }
        XCTAssertGreaterThan(alphas.filter { $0 < 10 }.count, alphas.count / 4, "Background must become transparent")
        XCTAssertGreaterThan(alphas.filter { $0 > 245 }.count, alphas.count / 10, "Subject must remain opaque")
        XCTAssertLessThan(output.pixels[3], 10, "Top-left background must be removed")
        XCTAssertGreaterThan(output.pixels[(320 * output.width + 240) * 4 + 3], 245, "Bottle centre must remain opaque")
        let png = try XCTUnwrap(result.pngData())
        XCTAssertEqual(try rgba(XCTUnwrap(UIImage(data: png))).pixels, output.pixels)

        let rotated = UIImage(cgImage: try XCTUnwrap(source.cgImage), scale: 1, orientation: .right)
        let normalized = BackgroundRemovalService.normalizedImage(rotated)
        attach(normalized, "orientation-right-normalized")
        let rotatedResult = try await BackgroundRemovalService.shared.removeBackground(from: rotated)
        attach(rotatedResult, "orientation-right-real-Vision-output")
        XCTAssertEqual(rotatedResult.imageOrientation, .up)
        XCTAssertEqual(rotatedResult.cgImage?.width, normalized.cgImage?.width)
        XCTAssertEqual(rotatedResult.cgImage?.height, normalized.cgImage?.height)
        let expected = UIImage(cgImage: try XCTUnwrap(result.cgImage), scale: 1, orientation: .right)
        let expectedPixels = try rgba(BackgroundRemovalService.normalizedImage(expected))
        let actual = try rgba(rotatedResult)
        let mismatchedAlpha = stride(from: 3, to: actual.pixels.count, by: 4).filter {
            abs(Int(actual.pixels[$0]) - Int(expectedPixels.pixels[$0])) > 128
        }.count
        XCTAssertLessThan(Double(mismatchedAlpha) / Double(actual.width * actual.height), 0.08,
                          "Rotating source must rotate the subject mask with it")
    }

    /// Only enabled explicitly on an isolated simulator containing synthetic
    /// fixtures. Never enumerate a physical device's or user's photo library.
    func testRealPhotosPNGWriteAndImportRoundTrip() async throws {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["CLEANCUT_PHOTOS_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Enable CLEANCUT_PHOTOS_ACCEPTANCE=1 only on a dedicated synthetic simulator")
        }
        #else
        throw XCTSkip("Photos fixture acceptance is restricted to a dedicated simulator")
        #endif
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        XCTAssertEqual(authorization, .authorized, "Grant Photos access only on the dedicated acceptance simulator")
        guard authorization == .authorized else { return }
        func identifiers() -> Set<String> {
            var values = Set<String>()
            PHAsset.fetchAssets(with: .image, options: nil).enumerateObjects { asset, _, _ in values.insert(asset.localIdentifier) }
            return values
        }
        let before = identifiers()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let fixture = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 16, y: 12, width: 32, height: 24))
        }
        let model = PhotoEditorViewModel() // Real production authorization and writer.
        model.processedImage = ProcessedImage(original: fixture, processed: fixture)
        let expected = try XCTUnwrap(model.prepareExport())
        let saved = await model.saveToPhotos()
        XCTAssertTrue(saved, model.errorMessage ?? "Production Photos write failed")
        let created = identifiers().subtracting(before)
        XCTAssertEqual(created.count, 1)
        let asset = try XCTUnwrap(PHAsset.fetchAssets(withLocalIdentifiers: Array(created), options: nil).firstObject)
        let resource = try XCTUnwrap(PHAssetResource.assetResources(for: asset).first)
        XCTAssertEqual(resource.uniformTypeIdentifier, "public.png")
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            let result = NSMutableData()
            PHAssetResourceManager.default().requestData(for: resource, options: nil, dataReceivedHandler: { result.append($0) }, completionHandler: { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result as Data) }
            })
        }
        let imported = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(imported.cgImage?.width, 64)
        XCTAssertEqual(imported.cgImage?.height, 48)
        XCTAssertEqual(try rgba(imported).pixels, try rgba(expected.image).pixels)
        attach(imported, "Photos-original-PNG-round-trip")
        // Retain the synthetic asset for actual Photos picker UI inspection.
        print("CLEANCUT_SYNTHETIC_PHOTO_ASSET=\(asset.localIdentifier)")
    }

    private func host<V: View>(_ content: V) throws -> (UIWindow, UIViewController?) {
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first { $0.isKeyWindow })
        let previous = window.rootViewController
        window.rootViewController = UIHostingController(rootView: content)
        window.makeKeyAndVisible()
        return (window, previous)
    }

    private func snapshot(_ window: UIWindow, name: String) {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        attach(image, name)
    }

    private func requireLandscapeOnIPad() async throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        // App-hosted unit tests cannot drive XCUIDevice orientation. Rotate the
        // dedicated simulator through Device Hub before running these tests.
        for _ in 0..<40 {
            if UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.interfaceOrientation.isLandscape == true { return }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTFail("The dedicated iPad did not enter native landscape orientation")
    }

    func testNativeShareSheetPresentation() async throws {
        guard ProcessInfo.processInfo.environment["CLEANCUT_UI_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Enable CLEANCUT_UI_ACCEPTANCE=1 on the dedicated acceptance simulator")
        }
        try await requireLandscapeOnIPad()
        let image = bottle()
        let export = PNGExport(image: image, data: try XCTUnwrap(image.pngData()))
        let (window, previous) = try host(ShareAcceptanceHost(export: export))
        defer { window.rootViewController = previous }
        if UIDevice.current.userInterfaceIdiom == .pad { XCTAssertGreaterThan(window.bounds.width, window.bounds.height) }
        try await Task.sleep(for: .seconds(3))
        snapshot(window, name: "native-PNG-share-sheet")
        func containsActivity(_ controller: UIViewController) -> Bool {
            if controller is UIActivityViewController { return true }
            if let presented = controller.presentedViewController, containsActivity(presented) { return true }
            return controller.children.contains(where: containsActivity)
        }
        XCTAssertTrue(containsActivity(try XCTUnwrap(window.rootViewController)), "SwiftUI sheet must present the real native share controller")
        // App-hosted tests cannot take XCUIScreen screenshots. This optional
        // bounded pause lets simctl/Device Hub capture the actual system sheet.
        if ProcessInfo.processInfo.environment["CLEANCUT_SCREEN_CAPTURE"] == "1" {
            print("CLEANCUT_SHARE_READY")
            try await Task.sleep(for: .seconds(30))
        }
    }

    func testEditorAtLargestDynamicType() async throws {
        guard ProcessInfo.processInfo.environment["CLEANCUT_UI_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Enable CLEANCUT_UI_ACCEPTANCE=1 on the dedicated acceptance simulator")
        }
        try await requireLandscapeOnIPad()
        let model = PhotoEditorViewModel()
        let image = bottle()
        let processed = ProcessedImage(original: image, processed: image)
        model.processedImage = processed
        let (window, previous) = try host(EditorView(processedImage: processed, onUpgrade: {}, viewModel: model)
            .environment(\.dynamicTypeSize, .accessibility5).background(Color.black).preferredColorScheme(.dark))
        defer { window.rootViewController = previous }
        try await Task.sleep(for: .seconds(1))
        snapshot(window, name: "editor-accessibility5")
        // SwiftUI's scroll implementation need not expose a UIScrollView. Use
        // real simulator interaction for reachability, rather than asserting
        // an implementation class. Keep the final viewport as review evidence.
        if ProcessInfo.processInfo.environment["CLEANCUT_SCREEN_CAPTURE"] == "1" {
            print("CLEANCUT_EDITOR_READY")
            try await Task.sleep(for: .seconds(60))
            snapshot(window, name: "editor-accessibility5-after-inspection")
        }
        // Attachments still require visual inspection. This does not certify
        // VoiceOver traversal or selection of a real share destination.
    }
}

private struct ShareAcceptanceHost: View {
    let export: PNGExport
    @State private var presented = false
    var body: some View {
        Color.black.onAppear { presented = true }
            .sheet(isPresented: $presented) { ActivityView(export: export) }
    }
}
