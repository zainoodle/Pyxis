import Foundation
import XCTest
@testable import PyxisCore

final class TryOnServiceTests: XCTestCase {
    override func tearDown() {
        TryOnURLProtocol.handler = nil
        super.tearDown()
    }

    func testConfigurationRejectsChangedPrivacyContract() async throws {
        for change in ["provider": "Another provider", "retention": "standard", "consentVersion": "new-version"] {
            var config: [String: Any] = ["available": true, "limit": 20, "provider": "xAI", "retention": "zero", "consentVersion": TryOnPrivacy.version]
            config[change.key] = change.value
            let payload = try JSONSerialization.data(withJSONObject: config)
            TryOnURLProtocol.handler = { request in (Self.response(request), payload) }
            do { _ = try await service().configuration(); XCTFail("Must require new privacy consent") }
            catch { XCTAssertEqual(error as? TryOnError, .unavailable) }
        }
    }

    func testRequestCarriesConsentPurchaseAndIdempotencyAndUsesServerBalance() async throws {
        let (url, data) = try photo()
        let job = UUID()
        TryOnURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/try-on/generate")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Transaction signed-proof")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Pyxis-Consent"), TryOnPrivacy.version)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), job.uuidString)
            return (Self.response(request, headers: Self.imageHeaders), data)
        }
        let result = try await service().generate(person: url, garments: [TryOnGarment(imageURL: url, category: .footwear, name: "Shoes")],
            authorization: "Transaction signed-proof", consent: TryOnPrivacy.version, jobID: job)
        XCTAssertEqual(result.imageData, data)
        XCTAssertEqual(result.allowance.remaining, 7)
        XCTAssertEqual(result.allowance.limit, 20)
    }

    func testConsentFailureNeverStartsUpload() async throws {
        TryOnURLProtocol.handler = { _ in XCTFail("No upload permitted"); throw URLError(.badURL) }
        let (url, _) = try photo()
        do {
            _ = try await service().generate(person: url, garments: [TryOnGarment(imageURL: url, category: .tops, name: "Top")],
                authorization: "Transaction signed-proof", consent: "outdated", jobID: UUID())
            XCTFail("Must reject outdated consent")
        } catch { XCTAssertEqual(error as? TryOnError, .consentRequired) }
    }

    func testRejectsCorruptResultsAndNonFiniteOrInconsistentQuotaHeaders() async throws {
        let (url, data) = try photo()
        for (headers, output) in [
            (Self.imageHeaders, Data([0xff, 0xd8, 0xff, 0xd9])),
            (Self.imageHeaders.merging(["X-Pyxis-Renews-At": "nan"]) { _, new in new }, data),
            (Self.imageHeaders.merging(["X-Pyxis-Remaining": "21"]) { _, new in new }, data),
            (Self.imageHeaders.merging(["Content-Length": "999999999"]) { _, new in new }, data)
        ] {
            TryOnURLProtocol.handler = { request in (Self.response(request, headers: headers), output) }
            do {
                _ = try await service().generate(person: url, garments: [TryOnGarment(imageURL: url, category: .tops, name: "Top")],
                    authorization: "Transaction signed-proof", consent: TryOnPrivacy.version, jobID: UUID())
                XCTFail("Must reject invalid result")
            } catch { XCTAssertEqual(error as? TryOnError, .invalidResponse) }
        }
    }

    func testRejectsUnsafeGatewayURLs() {
        for address in ["http://gateway.example", "https://user:pass@gateway.example", "https://gateway.example?key=secret", "https://gateway.example#fragment"] {
            XCTAssertFalse(TryOnService(baseURL: URL(string: address)).isConfigured)
        }
    }

    private func service() -> TryOnService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TryOnURLProtocol.self]
        return TryOnService(baseURL: URL(string: "https://gateway.example"), session: URLSession(configuration: config))
    }
    private func photo() throws -> (URL, Data) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("try-on-http-\(UUID()).jpg")
        let data = try XCTUnwrap(makeTestImage().jpegDataForTests())
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return (url, data)
    }
    private static let imageHeaders = ["Content-Type": "image/jpeg", "X-Pyxis-Remaining": "7", "X-Pyxis-Limit": "20", "X-Pyxis-Renews-At": "1900000000000"]
    private static func response(_ request: URLRequest, headers: [String: String] = ["Content-Type": "application/json"]) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)!
    }
}

private final class TryOnURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
