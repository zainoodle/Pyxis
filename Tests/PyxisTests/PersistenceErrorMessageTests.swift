import XCTest
@testable import PyxisCore

final class PersistenceErrorMessageTests: XCTestCase {
    func testUsesStableUserFacingCopyForSaveFailures() {
        let error = NSError(domain: "PyxisTests", code: 1)

        XCTAssertEqual(
            PersistenceErrorMessage.saveFailed(error),
            "Changes could not be saved. Please try again."
        )
    }
}
