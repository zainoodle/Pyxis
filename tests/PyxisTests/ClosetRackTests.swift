import CoreGraphics
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
                    let frame = GarmentRackGeometry.imageFrame(displaySize: size, visibleBounds: bounds, in: container, drop: drop)
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
}
