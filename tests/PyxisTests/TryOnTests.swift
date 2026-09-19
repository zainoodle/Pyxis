import Foundation
import XCTest
@testable import PyxisCore

@MainActor
final class TryOnTests: XCTestCase {
    private func storage() throws -> TryOnStorageService {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("try-on-tests-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try TryOnStorageService(rootURL: root)
    }
    private func preferences() -> UserDefaults {
        let name = "try-on-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    private func photo() throws -> Data { try XCTUnwrap(makeTestImage().jpegDataForTests()) }

    func testReferenceIsOnlyPersistentWhenRememberedAndCanBeRemoved() throws {
        let store = try storage()
        let url = try store.importPhoto(photo())
        XCTAssertNil(store.savedReferenceURL)
        try store.rememberReference(url)
        let persisted = try XCTUnwrap(store.savedReferenceURL)
        store.endSession()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: persisted.path))
        try store.forgetReference()
        XCTAssertNil(store.savedReferenceURL)
    }

    func testSavedPreviewSurvivesSessionAndDeduplicatesSave() throws {
        let store = try storage()
        let url = try store.storeGenerated(photo())
        let id = UUID()
        let first = try store.savePreview(at: url, names: ["Shoes"], id: id)
        _ = try store.savePreview(at: url, names: ["Shoes"], id: id)
        XCTAssertEqual(try store.previews().count, 1)
        store.endSession()
        let reopened = try TryOnStorageService(rootURL: store.rootURL)
        XCTAssertEqual(try reopened.previews(), [first])
        XCTAssertTrue(FileManager.default.fileExists(atPath: reopened.imageURL(for: first).path))
        try reopened.delete(first)
        XCTAssertTrue(try reopened.previews().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reopened.imageURL(for: first).path))
    }

    func testAbandonedSessionsAreRemovedWithoutTouchingActiveSessions() throws {
        let store = try storage()
        let active = try store.importPhoto(photo())
        let abandoned = store.rootURL.appendingPathComponent("Sessions/old-process")
        try FileManager.default.createDirectory(at: abandoned, withIntermediateDirectories: true)
        try photo().write(to: abandoned.appendingPathComponent("private.jpg"))
        _ = try TryOnStorageService(rootURL: store.rootURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: active.path))
    }

    func testFutureStorageVersionIsPreserved() throws {
        let store = try storage()
        let data = Data("{\"version\":99,\"previews\":[]}".utf8)
        let manifest = store.rootURL.appendingPathComponent("manifest.json")
        try data.write(to: manifest)
        XCTAssertThrowsError(try store.previews()) { XCTAssertEqual($0 as? TryOnError, .storageVersion) }
        XCTAssertEqual(try Data(contentsOf: manifest), data)
    }

    func testConsentIsRequiredAndRevocableWithoutSendingPhotos() async throws {
        let service = TryOnStub(data: try photo())
        let model = TryOnViewModel(service: service, storage: try storage(), preferences: preferences())
        await model.generate(authorization: "test")
        let calls = await service.calls
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.errorMessage, TryOnError.consentRequired.localizedDescription)
        model.acceptConsent(); XCTAssertTrue(model.hasConsent)
        model.revokeConsent(); XCTAssertFalse(model.hasConsent)
    }

    func testGenerationUsesOriginalAndServerAllowanceAndCanSave() async throws {
        let service = TryOnStub(data: try photo())
        let store = try storage()
        let garment = TryOnGarment(imageURL: try store.importPhoto(photo()), category: .footwear, name: "Shoes")
        let model = TryOnViewModel(garments: [garment], service: service, storage: store, preferences: preferences())
        await model.load(); await model.refreshAllowance(authorization: "test")
        await model.importPhoto(try photo(), forPerson: true)
        let reference = model.personURL
        model.acceptConsent(); XCTAssertTrue(model.canGenerate)
        await model.generate(authorization: "test")
        XCTAssertEqual(model.allowance?.remaining, 19)
        XCTAssertNotNil(model.generatedURL)
        XCTAssertEqual(model.personURL, reference)
        model.saveResult(); XCTAssertTrue(model.resultSaved)
        XCTAssertEqual(model.previews.count, 1)
        await model.generate(authorization: "test")
        let persons = await service.persons
        let jobs = await service.jobs
        XCTAssertEqual(persons, [reference!, reference!])
        XCTAssertNotEqual(jobs[0], jobs[1])
    }

    func testTransportRetryReusesGenerationIDAndPreservesInputs() async throws {
        let service = TryOnStub(data: try photo(), fails: true)
        let store = try storage()
        let garment = TryOnGarment(imageURL: try store.importPhoto(photo()), category: .tops, name: "Top")
        let model = TryOnViewModel(garments: [garment], service: service, storage: store, preferences: preferences())
        await model.load(); await model.refreshAllowance(authorization: "test")
        await model.importPhoto(try photo(), forPerson: true); model.acceptConsent()
        await model.generate(authorization: "test"); await model.generate(authorization: "test")
        let jobs = await service.jobs
        XCTAssertEqual(jobs.count, 2); XCTAssertEqual(jobs.first, jobs.last)
        XCTAssertEqual(model.garments, [garment]); XCTAssertNotNil(model.personURL)
        XCTAssertFalse(model.isGenerating); XCTAssertEqual(model.allowance?.remaining, 20)
    }

    func testExpiredReplayAllowsDeliberateNewGenerationInsteadOfTrappingRetries() async throws {
        let service = TryOnStub(data: try photo(), replayExpired: true)
        let store = try storage()
        let garment = TryOnGarment(imageURL: try store.importPhoto(photo()), category: .tops, name: "Top")
        let model = TryOnViewModel(garments: [garment], service: service, storage: store, preferences: preferences())
        await model.load(); await model.refreshAllowance(authorization: "test")
        await model.importPhoto(try photo(), forPerson: true); model.acceptConsent()
        await model.generate(authorization: "test")
        XCTAssertEqual(model.errorMessage, TryOnError.alreadyGenerated.localizedDescription)
        let beforeRetry = await service.calls
        XCTAssertEqual(beforeRetry, 1, "Never automatically spend another credit")
        await model.generate(authorization: "test")
        let jobs = await service.jobs
        XCTAssertNotEqual(jobs.first, jobs.last)
    }

    func testOptingOutOfRememberKeepsCurrentSessionUsable() async throws {
        let store = try storage()
        try store.rememberReference(store.importPhoto(photo()))
        let model = TryOnViewModel(storage: store, preferences: preferences())
        XCTAssertTrue(model.rememberPhoto)
        model.setRememberPhoto(false)
        XCTAssertNil(store.savedReferenceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(model.personURL).path))
        model.removeReference(); XCTAssertNil(model.personURL)
    }
}

private actor TryOnStub: TryOnProviding {
    nonisolated let isConfigured = true
    let data: Data
    let fails: Bool
    let replayExpired: Bool
    var calls = 0
    var persons: [URL] = []
    var jobs: [UUID] = []
    init(data: Data, fails: Bool = false, replayExpired: Bool = false) { self.data = data; self.fails = fails; self.replayExpired = replayExpired }
    func configuration() async throws -> TryOnConfiguration {
        TryOnConfiguration(available: true, limit: 20, consentVersion: TryOnPrivacy.version, provider: "xAI", retention: "zero")
    }
    func allowance(authorization: String) async throws -> TryOnAllowance {
        TryOnAllowance(limit: 20, remaining: 20, renewsAt: Date().addingTimeInterval(86400).timeIntervalSince1970 * 1000)
    }
    func generate(person: URL, garments: [TryOnGarment], authorization: String, consent: String, jobID: UUID) async throws -> TryOnResult {
        calls += 1; persons.append(person); jobs.append(jobID)
        if fails { throw URLError(.timedOut) }
        if replayExpired { throw TryOnError.alreadyGenerated }
        return TryOnResult(imageData: data, allowance: TryOnAllowance(limit: 20, remaining: 19, renewsAt: Date().addingTimeInterval(86400).timeIntervalSince1970 * 1000))
    }
}
