import XCTest
@testable import PyxisCore

@MainActor
final class TryOnEntryTests: XCTestCase {
    func testUnconfiguredFeatureHasNoEntryEvenIfServiceWouldReportAvailable() async {
        let model = TryOnEntryViewModel(service: EntryService(available: true, isConfigured: false), storage: nil)
        await model.load()
        XCTAssertNil(model.destination)
    }

    func testUnreadableSavedManifestKeepsGalleryRecoveryReachable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("entry-tests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try TryOnStorageService(rootURL: root)
        try Data("{\"version\":2,\"previews\":[]}".utf8).write(to: root.appendingPathComponent("manifest.json"))
        let model = TryOnEntryViewModel(service: EntryService(available: false), storage: storage)
        await model.load()
        XCTAssertEqual(model.destination, .savedPreviews)
    }

    func testUnavailableFeatureWithoutPreviewsHasNoEntry() async {
        let model = TryOnEntryViewModel(service: EntryService(available: false), storage: nil)
        await model.load()
        XCTAssertNil(model.destination)
    }

    func testAvailableFeatureHasGenerateEntry() async {
        let model = TryOnEntryViewModel(service: EntryService(available: true), storage: nil)
        await model.load()
        XCTAssertEqual(model.destination, .generate)
    }

    func testSavedPreviewsStayReachableWhenConfigurationFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("entry-tests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try TryOnStorageService(rootURL: root)
        let photo = try XCTUnwrap(makeTestImage().jpegDataForTests())
        let url = try storage.importPhoto(photo)
        _ = try storage.savePreview(at: url, names: ["Tee"], id: UUID())
        let model = TryOnEntryViewModel(service: EntryService(available: false, fails: true), storage: storage)
        await model.load()
        XCTAssertEqual(model.destination, .savedPreviews)
    }
}

private struct EntryService: TryOnProviding {
    let available: Bool
    var fails = false
    var isConfigured = true
    func configuration() async throws -> TryOnConfiguration {
        if fails { throw TryOnError.unavailable }
        return TryOnConfiguration(available: available, limit: 20, consentVersion: TryOnPrivacy.version, provider: "xAI", retention: "zero")
    }
    func allowance(authorization: String) async throws -> TryOnAllowance { throw TryOnError.unavailable }
    func generate(person: URL, garments: [TryOnGarment], authorization: String, consent: String, jobID: UUID) async throws -> TryOnResult {
        XCTFail("Entry checks must never upload photos")
        throw TryOnError.unavailable
    }
}
