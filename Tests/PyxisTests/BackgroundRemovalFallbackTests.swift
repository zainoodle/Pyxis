import CoreImage
import XCTest
@testable import PyxisCore

final class BackgroundRemovalFallbackTests: XCTestCase {
    func testMaskStatsReadGrayscaleInsteadOfOpaqueOutputAlpha() throws {
        let width = 4
        let height = 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) {
            pixels[index * 4 + 3] = 255
        }
        for x in 1...2 {
            let offset = (width + x) * 4
            pixels[offset] = 255
            pixels[offset + 1] = 255
            pixels[offset + 2] = 255
        }

        let mask = CIImage(
            bitmapData: Data(pixels),
            bytesPerRow: width * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let stats = try XCTUnwrap(
            BackgroundMaskInstanceStats(
                instance: 7,
                maskImage: mask,
                ciContext: CIContext(options: [.useSoftwareRenderer: true])
            )
        )

        XCTAssertEqual(stats.areaFraction, 0.125, accuracy: 0.001)
        XCTAssertEqual(stats.centroidX, 0.5, accuracy: 0.001)
        XCTAssertEqual(stats.centroidY, 1.0 / 3.0, accuracy: 0.001)
    }

    func testForegroundSelectorDropsSmallSideFragments() {
        let pants = BackgroundMaskInstanceStats(
            instance: 1,
            areaFraction: 0.28,
            centroidX: 0.50,
            centroidY: 0.45,
            minX: 0.32,
            maxX: 0.68,
            minY: 0.08,
            maxY: 0.86
        )
        let leftArm = BackgroundMaskInstanceStats(
            instance: 2,
            areaFraction: 0.035,
            centroidX: 0.15,
            centroidY: 0.50,
            minX: 0.08,
            maxX: 0.22,
            minY: 0.28,
            maxY: 0.72
        )
        let rightArm = BackgroundMaskInstanceStats(
            instance: 3,
            areaFraction: 0.032,
            centroidX: 0.85,
            centroidY: 0.48,
            minX: 0.78,
            maxX: 0.92,
            minY: 0.30,
            maxY: 0.70
        )

        let selected = BackgroundMaskInstanceSelector.selectedInstances(
            from: [leftArm, pants, rightArm]
        )

        XCTAssertEqual(selected, IndexSet(integer: 1))
    }

    func testForegroundSelectorKeepsSimilarClothingPairs() {
        let leftShoe = BackgroundMaskInstanceStats(
            instance: 1,
            areaFraction: 0.08,
            centroidX: 0.38,
            centroidY: 0.44,
            minX: 0.22,
            maxX: 0.48,
            minY: 0.30,
            maxY: 0.58
        )
        let rightShoe = BackgroundMaskInstanceStats(
            instance: 2,
            areaFraction: 0.075,
            centroidX: 0.62,
            centroidY: 0.45,
            minX: 0.52,
            maxX: 0.78,
            minY: 0.31,
            maxY: 0.59
        )
        let hand = BackgroundMaskInstanceStats(
            instance: 3,
            areaFraction: 0.015,
            centroidX: 0.90,
            centroidY: 0.60,
            minX: 0.84,
            maxX: 0.96,
            minY: 0.52,
            maxY: 0.68
        )

        let selected = BackgroundMaskInstanceSelector.selectedInstances(
            from: [leftShoe, rightShoe, hand]
        )

        XCTAssertEqual(selected, IndexSet([1, 2]))
    }

    func testFailurePreservesOriginalAndAllowsSaveWithoutCutout() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "source.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let service = FailingBackgroundRemovalService(imageStorage: storage)

        let result = await service.processImage(at: source, itemID: UUID())

        XCTAssertEqual(result.status, .failed)
        XCTAssertFalse(result.originalPath.isEmpty)
        XCTAssertNil(result.cutoutPath)
        XCTAssertEqual(result.errorMessage, "Background removal failed — retry")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(for: result.originalPath).path))
    }

    func testImportFailureUsesGenericMessage() async throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let service = FailingBackgroundRemovalService(imageStorage: storage)
        let missingSource = root.appendingPathComponent("missing.jpg")

        let result = await service.processImage(at: missingSource, itemID: UUID())

        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.originalPath.isEmpty)
        XCTAssertNil(result.cutoutPath)
        XCTAssertEqual(result.errorMessage, "Image import failed — try another image")
    }

    private func makeTemporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeImageFile(named name: String, root: URL) throws -> URL {
        let url = root.appendingPathComponent(name)
        let data = try XCTUnwrap(makeTestImage().jpegDataForTests())
        try data.write(to: url)
        return url
    }
}
