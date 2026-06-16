import XCTest
@testable import ArchiveCore

final class ClothingClassificationTests: XCTestCase {
    func testInfersSubtypeAndCategoryFromFilename() {
        let service = ClothingClassificationService()

        let result = service.classify(filename: "washed-black-hoodie.jpg")

        XCTAssertEqual(result.category, .tops)
        XCTAssertEqual(result.subtype, .hoodie)
        XCTAssertGreaterThan(result.confidence, 0)
    }

    func testDefaultsToOtherWhenNoHeuristicMatches() {
        let service = ClothingClassificationService()

        let result = service.classify(filename: "archive-import.jpg")

        XCTAssertEqual(result.category, .other)
        XCTAssertEqual(result.subtype, .other)
        XCTAssertEqual(result.confidence, 0)
    }
}
