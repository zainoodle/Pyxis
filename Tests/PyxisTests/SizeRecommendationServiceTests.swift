import XCTest
@testable import PyxisCore

final class SizeRecommendationServiceTests: XCTestCase {
    func testRecommendsSizeWhoseRelevantRangesContainProfile() {
        let profile = BodyProfile(
            fitPreference: .regular,
            chestCentimeters: 99,
            waistCentimeters: 84
        )
        let options = [
            RetailerSizeOption(label: "M", chestCentimeters: 92...97, waistCentimeters: 77...82),
            RetailerSizeOption(label: "L", chestCentimeters: 98...104, waistCentimeters: 83...89)
        ]

        let result = SizeRecommendationService().recommend(
            profile: profile,
            category: .top,
            options: options
        )

        XCTAssertEqual(result?.sizeLabel, "L")
        XCTAssertGreaterThan(result?.confidence ?? 0, 0.6)
        XCTAssertTrue(result?.explanation.contains("chest") == true)
    }

    func testCategoryUsesOnlyRelevantMeasurements() {
        let profile = BodyProfile(chestCentimeters: 130, waistCentimeters: 80, hipCentimeters: 98, inseamCentimeters: 76)
        let options = [
            RetailerSizeOption(label: "30", waistCentimeters: 76...81, hipCentimeters: 94...100, inseamCentimeters: 74...78),
            RetailerSizeOption(label: "40", chestCentimeters: 126...134, waistCentimeters: 100...106, hipCentimeters: 116...122)
        ]

        let result = SizeRecommendationService().recommend(profile: profile, category: .bottom, options: options)

        XCTAssertEqual(result?.sizeLabel, "30")
    }

    func testReturnsNilWithoutComparableChartMeasurements() {
        let profile = BodyProfile(heightCentimeters: 180, weightKilograms: 75)
        let option = RetailerSizeOption(label: "M", chestCentimeters: 94...100)

        XCTAssertNil(SizeRecommendationService().recommend(profile: profile, category: .top, options: [option]))
    }

    func testReturnsNilWhenProfileFallsOutsideEverySizeRange() {
        let profile = BodyProfile(chestCentimeters: 120, waistCentimeters: 105)
        let option = RetailerSizeOption(label: "M", chestCentimeters: 94...100, waistCentimeters: 78...84)

        XCTAssertNil(SizeRecommendationService().recommend(profile: profile, category: .top, options: [option]))
    }

    func testRecommendsFootwearFromFootLength() {
        let profile = BodyProfile(footLengthCentimeters: 27.2)
        let options = [
            RetailerSizeOption(label: "9", footLengthCentimeters: 25.5...26.5),
            RetailerSizeOption(label: "10", footLengthCentimeters: 27...27.5)
        ]

        let result = SizeRecommendationService().recommend(profile: profile, category: .footwear, options: options)

        XCTAssertEqual(result?.sizeLabel, "10")
    }
}
