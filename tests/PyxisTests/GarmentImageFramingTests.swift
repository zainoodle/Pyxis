import CoreImage
import ImageIO
import XCTest
@testable import PyxisCore

final class GarmentImageFramingTests: XCTestCase {
    private let context = CIContext(options: [.useSoftwareRenderer: true])

    func testFramesVisibleGarmentWithPaddingAndPreservesAspectRatio() throws {
        let image = cutout(
            canvas: CGRect(x: 0, y: 0, width: 200, height: 200),
            subject: CGRect(x: 70, y: 30, width: 60, height: 140)
        )
        let analysis = try XCTUnwrap(GarmentImageFraming.analyze(image, using: context))

        XCTAssertTrue(GarmentImageFraming.acceptsAutomaticCutout(analysis))
        XCTAssertEqual(analysis.visibleRect.minX, 70, accuracy: 2)
        XCTAssertEqual(analysis.visibleRect.minY, 30, accuracy: 2)
        XCTAssertGreaterThan(analysis.frameRect.width, analysis.visibleRect.width)
        XCTAssertGreaterThan(analysis.frameRect.height, analysis.visibleRect.height)
        XCTAssertLessThan(analysis.frameRect.width, 90)
        XCTAssertLessThan(analysis.frameRect.height, 180)

        let original = try XCTUnwrap(context.createCGImage(image, from: image.extent))
        let framed = GarmentImageFraming.framedDisplayImage(original, using: context)
        XCTAssertLessThan(framed.width, original.width)
        XCTAssertLessThan(framed.height, original.height)
        XCTAssertEqual(CGFloat(framed.width), analysis.frameRect.width, accuracy: 2)

        let encoded = try XCTUnwrap(context.pngRepresentation(
            of: image.cropped(to: analysis.frameRect),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(encoded as CFData, nil))
        let savedCutout = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(CGFloat(savedCutout.width), analysis.frameRect.width, accuracy: 2)
        XCTAssertEqual(CGFloat(savedCutout.height), analysis.frameRect.height, accuracy: 2)
    }

    func testAutomaticReviewRejectsEmptyTinyAndFullFrameMasks() throws {
        let canvas = CGRect(x: 0, y: 0, width: 200, height: 200)
        XCTAssertNil(GarmentImageFraming.analyze(
            CIImage(color: .clear).cropped(to: canvas), using: context
        ))

        let tiny = try XCTUnwrap(GarmentImageFraming.analyze(
            cutout(canvas: canvas, subject: CGRect(x: 98, y: 98, width: 4, height: 4)),
            using: context
        ))
        XCTAssertFalse(GarmentImageFraming.acceptsAutomaticCutout(tiny))

        let fullFrame = try XCTUnwrap(GarmentImageFraming.analyze(
            CIImage(color: .white).cropped(to: canvas), using: context
        ))
        XCTAssertFalse(GarmentImageFraming.acceptsAutomaticCutout(fullFrame))
    }

    func testDisplayFramingKeepsOriginalWhenNothingCanBeTrimmed() throws {
        let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 60))
        let original = try XCTUnwrap(context.createCGImage(image, from: image.extent))

        let displayed = GarmentImageFraming.framedDisplayImage(original, using: context)

        XCTAssertEqual(displayed.width, original.width)
        XCTAssertEqual(displayed.height, original.height)
    }

    private func cutout(canvas: CGRect, subject: CGRect) -> CIImage {
        CIImage(color: .white).cropped(to: subject)
            .composited(over: CIImage(color: .clear).cropped(to: canvas))
    }

    func testBalancedFramingFitsWideShoesAndNarrowTrousersWithoutDistortion() {
        let container = CGSize(width: 330, height: 420)
        for size in [CGSize(width: 700, height: 300), CGSize(width: 240, height: 900), CGSize(width: 600, height: 650)] {
            let display = GarmentImageFraming.balancedDisplaySize(imageSize: size, visibleFraction: 0.6, in: container)
            XCTAssertLessThanOrEqual(display.width, container.width * 0.9 + 0.01)
            XCTAssertLessThanOrEqual(display.height, container.height * 0.88 + 0.01)
            XCTAssertEqual(display.width / display.height, size.width / size.height, accuracy: 0.001)
        }
        let sparse = GarmentImageFraming.balancedDisplaySize(imageSize: container, visibleFraction: 0.3, in: container)
        let dense = GarmentImageFraming.balancedDisplaySize(imageSize: container, visibleFraction: 0.95, in: container)
        XCTAssertGreaterThan(sparse.height, dense.height)
    }
}
