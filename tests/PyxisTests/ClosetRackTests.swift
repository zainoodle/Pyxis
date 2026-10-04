import CoreGraphics
import CoreImage
import ImageIO
import XCTest
@testable import PyxisCore

final class ClosetRackTests: XCTestCase {
    func testSwayCanReverseWithoutJumpingAndReturnsToRest() {
        var sway = ClosetRackSway()
        sway.nudge(velocityChange: -900, at: 100)
        let before = sway.sample(at: 100.1)
        XCTAssertLessThan(before.angle, 0)
        sway.nudge(velocityChange: 1_400, at: 100.1)
        XCTAssertEqual(sway.sample(at: 100.1).angle, before.angle, accuracy: 0.000_001)
        XCTAssertGreaterThan(sway.sample(at: 100.1).velocity, before.velocity)
        XCTAssertEqual(sway.sample(at: 101.5).angle, 0, accuracy: 0.0001)
    }

    func testImpulseHasOneSmallCounterSwingBeforeSettling() {
        var sway = ClosetRackSway()
        sway.nudge(velocityChange: 900, at: 100)
        let firstSwing = sway.sample(at: 100.1).angle
        let counterSwing = sway.sample(at: 100.4).angle
        XCTAssertGreaterThan(firstSwing, 0)
        XCTAssertLessThan(counterSwing, 0)
        XCTAssertLessThan(abs(counterSwing), abs(firstSwing) * 0.3)
        XCTAssertLessThan(abs(sway.sample(at: 101.3).angle), 0.0001)
    }

    func testRapidAlternatingSwipesRemainBounded() {
        var sway = ClosetRackSway()
        for step in 0..<180 {
            let time = 100 + Double(step) / 60
            sway.nudge(velocityChange: step.isMultiple(of: 2) ? 10_000 : -10_000, at: time)
            for offset in [0.0, 0.016, 0.05] {
                XCTAssertLessThanOrEqual(abs(sway.sample(at: time + offset).angle), ClosetRackSway.maximumAngle)
            }
        }
        sway.reset()
        XCTAssertEqual(sway.sample(at: 104).angle, 0)
    }

    func testWideAndLongImagesKeepAspectRatioAndFitDuringSway() {
        let container = CGSize(width: 300, height: 350)
        for size in [CGSize(width: 280, height: 120), CGSize(width: 120, height: 290), CGSize(width: 265, height: 260)] {
            for bounds in [CGRect(x: 0, y: 0, width: 1, height: 1), CGRect(x: 0.12, y: 0.08, width: 0.7, height: 0.85)] {
                for drop in [GarmentRackGeometry.supportDrop, GarmentRackGeometry.clipSupportDrop] {
                    let frame = GarmentRackGeometry.imageFrame(displaySize: size, attachment: CGPoint(x: bounds.midX, y: bounds.minY), in: container, drop: drop)
                    XCTAssertEqual(frame.width / frame.height, size.width / size.height, accuracy: 0.000_001)
                    for sign in [-1.0, 1.0] {
                        let angle = ClosetRackSway.maximumAngle * sign
                        for x in [frame.minX, frame.maxX] {
                            for y in [frame.minY, frame.maxY] {
                                let dx = x - container.width / 2
                                let dy = y - GarmentRackGeometry.hookY
                                let rotatedX = container.width / 2 + dx * cos(angle) - dy * sin(angle)
                                let rotatedY = GarmentRackGeometry.hookY + dx * sin(angle) + dy * cos(angle)
                                XCTAssertGreaterThanOrEqual(rotatedX, 0)
                                XCTAssertLessThanOrEqual(rotatedX, container.width)
                                XCTAssertGreaterThanOrEqual(rotatedY, 0)
                                XCTAssertLessThanOrEqual(rotatedY, container.height)
                            }
                        }
                    }
                }
            }
        }
    }
    func testConservativeSupportsRejectAmbiguousSilhouettes() {
        let width = 100, height = 140
        func silhouette(neck: Bool = true, diagonal: Bool = false, opacity: UInt8 = 255) -> [UInt8] {
            var alpha = [UInt8](repeating: 0, count: width * height)
            for x in 10..<90 {
                let top = diagonal ? 15 + x / 3 : (neck && (44..<56).contains(x) ? 28 : 15)
                for y in top..<130 { alpha[y * width + x] = opacity }
            }
            return alpha
        }
        let shoulder = GarmentRackAttachment.analyze(alpha: silhouette(), width: width, height: height, support: .shoulder)
        guard let shoulder else { XCTFail("Expected a supported broad-shoulder silhouette"); return }
        XCTAssertEqual(shoulder.anchor.x, 0.495, accuracy: 0.015)
        XCTAssertEqual(shoulder.anchor.y, 15.0 / 140, accuracy: 0.001)
        XCTAssertNil(GarmentRackAttachment.analyze(alpha: silhouette(neck: false), width: width, height: height, support: .shoulder), "No neckline evidence means no invented shoulder support")
        XCTAssertNil(GarmentRackAttachment.analyze(alpha: silhouette(diagonal: true), width: width, height: height, support: .shoulder))
        XCTAssertNil(GarmentRackAttachment.analyze(alpha: silhouette(opacity: 150), width: width, height: height, support: .shoulder))
        XCTAssertNotNil(GarmentRackAttachment.analyze(alpha: silhouette(neck: false), width: width, height: height, support: .clips))
        XCTAssertNil(GarmentRackAttachment.analyze(alpha: silhouette(diagonal: true), width: width, height: height, support: .clips))
    }

    func testRackAttachmentUsesContourAnchorAndKeepsAllCornersInside() {
        let container = CGSize(width: 300, height: 350)
        let anchor = CGPoint(x: 0.46, y: 0.17)
        let size = CGSize(width: 230, height: 290)
        let frame = GarmentRackGeometry.imageFrame(displaySize: size, attachment: anchor, in: container)
        XCTAssertEqual(frame.width / frame.height, size.width / size.height, accuracy: 0.000001)
        XCTAssertEqual(frame.minX + frame.width * anchor.x, container.width / 2, accuracy: 0.000001)
        XCTAssertEqual(frame.minY + frame.height * anchor.y, GarmentRackGeometry.hookY + GarmentRackGeometry.supportDrop, accuracy: 0.000001)
        for sign in [-1.0, 1.0] {
            let angle = ClosetRackSway.maximumAngle * sign
            for x in [frame.minX, frame.maxX] {
                for y in [frame.minY, frame.maxY] {
                    let dx = x - container.width / 2, dy = y - GarmentRackGeometry.hookY
                    XCTAssertTrue((0...container.width).contains(container.width / 2 + dx * cos(angle) - dy * sin(angle)))
                    XCTAssertTrue((0...container.height).contains(GarmentRackGeometry.hookY + dx * sin(angle) + dy * cos(angle)))
                }
            }
        }
    }

    func testImageAnalysisUsesTopDownCoordinates() throws {
        let width = 100, height = 140
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for x in 10..<90 {
            let top = (44..<56).contains(x) ? 28 : 15
            for y in top..<130 {
                for channel in 0..<4 { pixels[(y * width + x) * 4 + channel] = 255 }
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let attachment = try XCTUnwrap(GarmentRackAttachment.analyze(image, support: .shoulder, context: CIContext()))
        XCTAssertEqual(attachment.anchor.y, 15.0 / 140, accuracy: 0.01)
    }

    func testVeryWideShortCutoutFallsBackWithoutInvalidSamplingRange() {
        let width = 192, height = 32
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 5..<27 {
            for x in 2..<190 { alpha[y * width + x] = 255 }
        }
        XCTAssertNil(GarmentRackAttachment.analyze(alpha: alpha, width: width, height: height, support: .clips))
        XCTAssertNil(GarmentRackAttachment.analyze(alpha: alpha, width: width, height: height, support: .shoulder))
    }

}
