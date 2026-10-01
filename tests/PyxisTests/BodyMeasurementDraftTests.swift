import XCTest
@testable import PyxisCore

final class BodyMeasurementDraftTests: XCTestCase {
    func testLoadingMetricProfileKeepsSavedNumbersWithoutConvertingAgain() {
        let profile = BodyProfile(measurementSystem: .metric, weightKilograms: 75,
                                  chestCentimeters: 99, waistCentimeters: 84)
        let draft = BodyMeasurementDraft(profile: profile)
        XCTAssertEqual(draft.system, .metric)
        XCTAssertEqual(draft.values[.chest], "99")
        XCTAssertEqual(draft.values[.waist], "84")
        XCTAssertEqual(draft.canonical(.chest), 99)
        XCTAssertEqual(draft.canonical(.weight), 75)
    }

    func testLoadingImperialProfileDisplaysInchesAndPounds() {
        let profile = BodyProfile(measurementSystem: .imperial, weightKilograms: 45.359237,
                                  chestCentimeters: 101.6)
        let draft = BodyMeasurementDraft(profile: profile)
        XCTAssertEqual(draft.values[.chest], "40")
        XCTAssertEqual(draft.values[.weight], "100")
        XCTAssertEqual(draft.canonical(.chest), 101.6)
    }

    func testChangingUnitsConvertsLengthAndWeightOnlyOnce() throws {
        var draft = BodyMeasurementDraft(system: .imperial, values: [.chest: "40", .weight: "100"])
        draft.changeUnits(to: .metric)
        XCTAssertEqual(try XCTUnwrap(draft.canonical(.chest)), 101.6, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(draft.canonical(.weight)), 45.4, accuracy: 0.01)
        let values = draft.values
        draft.changeUnits(to: .metric)
        XCTAssertEqual(draft.values, values)
        draft.changeUnits(to: .imperial)
        XCTAssertEqual(draft.values[.chest], "40")
        XCTAssertEqual(draft.values[.weight], "100.1")
    }

    func testBlankAndInvalidInputRemainOptionalDuringUnitChanges() {
        var draft = BodyMeasurementDraft(values: [.chest: "", .waist: "invalid", .hip: "0", .height: "-2"])
        draft.changeUnits(to: .metric)
        XCTAssertEqual(draft.values[.waist], "invalid")
        for key in [MeasurementKey.chest, .waist, .hip, .height] { XCTAssertNil(draft.canonical(key)) }
    }
}
