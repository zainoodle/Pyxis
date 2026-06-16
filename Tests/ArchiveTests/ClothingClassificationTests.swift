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

    func testInfersCommonFashionTermsFromFilename() {
        let service = ClothingClassificationService()
        let cases: [(String, ClothingCategory, ClothingSubtype)] = [
            ("stone-cargo-pants.png", .bottoms, .pants),
            ("ribbed-tank-top.heic", .tops, .shirt),
            ("wool-overshirt.jpeg", .outerwear, .jacket),
            ("black-loafers.jpg", .footwear, .sneakers),
            ("silver-bracelet.png", .accessories, .jewelry)
        ]

        for (filename, expectedCategory, expectedSubtype) in cases {
            let result = service.classify(filename: filename)

            XCTAssertEqual(result.category, expectedCategory, filename)
            XCTAssertEqual(result.subtype, expectedSubtype, filename)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.55, filename)
        }
    }

    func testInfersBroaderWardrobeVocabularyFromFilename() {
        let service = ClothingClassificationService()
        let cases: [(String, ClothingCategory, ClothingSubtype)] = [
            ("cream-cardigan.jpeg", .tops, .cardigan),
            ("quilted-puffer-vest.png", .outerwear, .vest),
            ("green-raincoat.heic", .outerwear, .coat),
            ("matte-black-leggings.png", .bottoms, .leggings),
            ("athletic-joggers.jpeg", .bottoms, .joggers),
            ("leather-mules.jpg", .footwear, .mules),
            ("silk-scarf.png", .accessories, .scarf),
            ("tortoise-sunglasses.jpg", .accessories, .sunglasses),
            ("gold-watch.png", .accessories, .watch)
        ]

        for (filename, expectedCategory, expectedSubtype) in cases {
            let result = service.classify(filename: filename)

            XCTAssertEqual(result.category, expectedCategory, filename)
            XCTAssertEqual(result.subtype, expectedSubtype, filename)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.55, filename)
        }
    }

    func testDoesNotMatchTokensInsideUnrelatedWords() {
        let service = ClothingClassificationService()

        let result = service.classify(filename: "caption-reference-photo.jpg")

        XCTAssertEqual(result.category, .other)
        XCTAssertEqual(result.subtype, .other)
        XCTAssertEqual(result.confidence, 0)
    }

    func testDefaultsToOtherWhenNoHeuristicMatches() {
        let service = ClothingClassificationService()

        let result = service.classify(filename: "archive-import.jpg")

        XCTAssertEqual(result.category, .other)
        XCTAssertEqual(result.subtype, .other)
        XCTAssertEqual(result.confidence, 0)
    }
}
