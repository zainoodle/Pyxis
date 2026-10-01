import XCTest
@testable import PyxisCore

final class TagEntryDraftTests: XCTestCase {
    func testUnsubmittedInputIsIncludedWhenFormSaves() {
        var draft = TagEntryDraft(text: "work")
        draft.updateInput(" summer ")
        XCTAssertEqual(draft.text, "work, summer")
        XCTAssertEqual(TagEntryDraft(text: draft.text).tags, ["work", "summer"])
    }

    func testCommittingMultipleTagsPreservesOrderWithoutEmptyValues() {
        var draft = TagEntryDraft(text: "work")
        draft.updateInput(" summer, , linen ")
        draft.commitInput()
        XCTAssertEqual(draft.tags, ["work", "summer", "linen"])
        XCTAssertEqual(draft.input, "")
        XCTAssertEqual(draft.text, "work, summer, linen")
    }

    func testRemovingOneDuplicatePreservesOtherTagsAndPendingInput() {
        var draft = TagEntryDraft(text: "work, work, summer")
        draft.updateInput("linen")
        draft.remove(at: 1)
        XCTAssertEqual(draft.text, "work, summer, linen")
    }

    func testTypingPastCommaDoesNotCommitPrefixesOrDuplicateTags() {
        var draft = TagEntryDraft(text: "work")
        let input = "casual,weekday"
        for length in 1...input.count { draft.updateInput(String(input.prefix(length))) }
        XCTAssertEqual(draft.tags, ["work"])
        XCTAssertEqual(TagEntryDraft(text: draft.text).tags, ["work", "casual", "weekday"])
        draft.commitInput()
        XCTAssertEqual(draft.tags, ["work", "casual", "weekday"])
        XCTAssertEqual(draft.input, "")
    }
}
