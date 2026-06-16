import UIKit
import XCTest
@testable import ArchiveCore

final class ColorAnalysisTests: XCTestCase {
    func testMapsSolidColorsToClosetColors() throws {
        let cases: [(UIColor, ClosetColor)] = [
            (.black, .black),
            (.white, .white),
            (.gray, .gray),
            (.red, .red),
            (.blue, .blue),
            (.green, .green),
            (.yellow, .yellow),
            (.orange, .orange),
            (UIColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1), .brown),
            (UIColor(red: 0.02, green: 0.05, blue: 0.22, alpha: 1), .navy)
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

    private func makeImageFile(color: UIColor) throws -> URL {
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
                ? UIColor(red: 1, green: 0, blue: 0, alpha: 0)
                : UIColor.blue
        }
    }

    private func makeFullyTransparentImage() throws -> URL {
        try makeCustomRGBAImage { _, _, _ in
            UIColor(red: 1, green: 1, blue: 1, alpha: 0)
        }
    }

    private func makeCustomRGBAImage(
        colorAt: (Int, Int, Int) -> UIColor
    ) throws -> URL {
        let size = CGSize(width: 12, height: 12)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            for y in 0..<Int(size.height) {
                for x in 0..<Int(size.width) {
                    colorAt(x, y, Int(size.width)).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let data = try XCTUnwrap(image.pngData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ARCHIVE-custom-\(UUID().uuidString).png")
        try data.write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
