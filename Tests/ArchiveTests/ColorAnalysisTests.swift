import AppKit
import XCTest
@testable import ArchiveCore

final class ColorAnalysisTests: XCTestCase {
    func testMapsSolidColorsToClosetColors() throws {
        let cases: [(NSColor, ClosetColor)] = [
            (.black, .black),
            (.white, .white),
            (.gray, .gray),
            (.red, .red),
            (.blue, .blue),
            (.green, .green),
            (.yellow, .yellow),
            (.orange, .orange),
            (NSColor(calibratedRed: 0.45, green: 0.25, blue: 0.12, alpha: 1), .brown),
            (NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.22, alpha: 1), .navy)
        ]

        for (color, expected) in cases {
            let url = try makeImageFile(color: color)
            let result = try ColorAnalysisService().analyze(imageURL: url)
            XCTAssertEqual(result.primaryColor, expected)
        }
    }

    func testIgnoresTransparentPixels() throws {
        let url = try makeHalfTransparentHalfBlueImage()
        let result = try ColorAnalysisService().analyze(imageURL: url)

        XCTAssertEqual(result.primaryColor, .blue)
    }

    func testReturnsUnknownWhenNoVisiblePixelsExist() throws {
        let url = try makeFullyTransparentImage()
        let result = try ColorAnalysisService().analyze(imageURL: url)

        XCTAssertEqual(result.primaryColor, .unknown)
        XCTAssertEqual(result.confidence, 0)
    }

    private func makeImageFile(color: NSColor) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ARCHIVE-color-\(UUID().uuidString).png")
        let data = try XCTUnwrap(makeTestImage(color: color).pngDataForTests())
        try data.write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeHalfTransparentHalfBlueImage() throws -> URL {
        try makeCustomRGBAImage { x, _, width in
            x < width / 2
                ? NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0)
                : NSColor.blue
        }
    }

    private func makeFullyTransparentImage() throws -> URL {
        try makeCustomRGBAImage { _, _, _ in
            NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0)
        }
    }

    private func makeCustomRGBAImage(
        colorAt: (Int, Int, Int) -> NSColor
    ) throws -> URL {
        let width = 12
        let height = 12
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        for y in 0..<height {
            for x in 0..<width {
                bitmap.setColor(colorAt(x, y, width), atX: x, y: y)
            }
        }

        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ARCHIVE-custom-\(UUID().uuidString).png")
        try data.write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
