import CoreImage
import XCTest
@testable import PyxisCore

final class GarmentMaskRefinementTests: XCTestCase {
    func testPromptsFollowOffCenterGarmentAndAvoidStrayObject() {
        let width = 100, height = 100
        var mask = [UInt8](repeating: 0, count: width * height)
        for y in 15..<85 { for x in 10..<40 { mask[y * width + x] = 255 } }
        for y in 30..<40 { for x in 80..<90 { mask[y * width + x] = 255 } }
        let points = GarmentMaskRefinement.promptPoints(mask: mask, width: width, height: height)
        XCTAssertEqual(points.count, 3)
        for point in points {
            XCTAssertGreaterThan(point.x, 0.1)
            XCTAssertLessThan(point.x, 0.4)
            XCTAssertGreaterThan(point.y, 0.15)
            XCTAssertLessThan(point.y, 0.85)
        }
        XCTAssertGreaterThan(points[1].x, points[0].x)
        XCTAssertGreaterThan(points[2].y, points[0].y)
    }

    func testCleanupDropsDetachedScrapAndFillsOnlyTinyInteriorHoles() throws {
        let width = 40, height = 40
        var logits = [Float](repeating: -8, count: width * height)
        for y in 8..<32 { for x in 8..<32 { logits[y * width + x] = 8 } }
        logits[2 * width + 2] = 8
        logits[3 * width + 3] = -0.1
        logits[12 * width + 12] = -8
        for y in 18..<23 { for x in 18..<23 { logits[y * width + x] = -8 } }
        let cleaned = try XCTUnwrap(GarmentMaskRefinement.cleanedLogits(logits, width: width, height: height))
        XCTAssertLessThan(cleaned[2 * width + 2], -1)
        XCTAssertLessThan(cleaned[3 * width + 3], -1)
        XCTAssertGreaterThan(cleaned[12 * width + 12], 0)
        XCTAssertLessThan(cleaned[20 * width + 20], 0)
        XCTAssertEqual(cleaned[10 * width + 10], 8)
    }

    func testCleanupKeepsTwoSimilarPieces() throws {
        var logits = [Float](repeating: -8, count: 40 * 40)
        for y in 10..<30 { for x in 5..<15 { logits[y * 40 + x] = 8 } }
        for y in 10..<30 { for x in 25..<35 { logits[y * 40 + x] = 8 } }
        let points = GarmentMaskRefinement.promptPoints(mask: logits.map { $0 > 0 ? 255 : 0 }, width: 40, height: 40)
        XCTAssertTrue(points.contains { $0.x < 0.4 })
        XCTAssertTrue(points.contains { $0.x > 0.6 })
        let cleaned = try XCTUnwrap(GarmentMaskRefinement.cleanedLogits(logits, width: 40, height: 40))
        XCTAssertGreaterThan(cleaned[20 * 40 + 10], 0)
        XCTAssertGreaterThan(cleaned[20 * 40 + 30], 0)
    }

    func testRejectsMalformedOrEmptyMask() {
        XCTAssertNil(GarmentMaskRefinement.cleanedLogits([.nan], width: 1, height: 1))
        XCTAssertNil(GarmentMaskRefinement.cleanedLogits([1], width: 2, height: 2))
        XCTAssertNil(GarmentMaskRefinement.cleanedLogits(Array(repeating: -8, count: 100), width: 10, height: 10))
        XCTAssertTrue(GarmentMaskRefinement.promptPoints(mask: [], width: 0, height: 0).isEmpty)
    }

    /// Optional local integration check. Private wardrobe images never enter the repository.
    func testLocalSAMFixtureWhenProvided() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let sourcePath = env["PYXIS_CUTOUT_FIXTURE"],
              let modelPath = env["PYXIS_CUTOUT_MODELS"],
              let outputPath = env["PYXIS_CUTOUT_OUTPUT"] else {
            throw XCTSkip("Set local fixture, compiled model directory, and output paths to run model inference.")
        }
        let context = CIContext()
        let source = try LocalBackgroundRemovalService.orientationCorrectedImage(from: URL(fileURLWithPath: sourcePath))
        let hint = try? LocalBackgroundRemovalService.bestForegroundMask(for: source, ciContext: context)
        let segmenter = SAMGarmentSegmenter(modelDirectory: URL(fileURLWithPath: modelPath))
        // Exercise the same no-Vision route used when iOS cannot supply a foreground hint.
        let fallbackMask = try await segmenter.mask(for: source, foregroundHint: nil)
        let fallbackStats = try XCTUnwrap(BackgroundMaskInstanceStats(instance: 0, maskImage: fallbackMask, ciContext: context))
        XCTAssertNotNil(BackgroundMaskCandidateSelector.preferredCandidateIndex(from: [fallbackStats]))
        let rawMask = try await segmenter.mask(for: source, foregroundHint: hint)
        let mask = GarmentPhotoRefinementService.refinedMask(rawMask, extent: source.extent)
        let output = source.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: mask,
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: source.extent)
        ])
        let framing = try XCTUnwrap(GarmentImageFraming.analyze(output, using: context))
        XCTAssertTrue(GarmentImageFraming.acceptsAutomaticCutout(framing))
        let png = try XCTUnwrap(context.pngRepresentation(of: output.cropped(to: framing.frameRect),
                                                          format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        try png.write(to: URL(fileURLWithPath: outputPath))
    }
}
