import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import PyxisCore

final class AIGarmentStudioServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testCleanupBuildsExactRouteAndAuthenticationWithoutMisleadingIdempotency() async throws {
        let imageURL = try makeSourceImage()
        var capturedRequest: URLRequest?
        URLProtocolStub.requestHandler = { request in
            capturedRequest = request
            return Self.imageResponse(for: request)
        }
        let service = makeService()

        let result = try await service.makePristineGarment(from: imageURL)

        XCTAssertEqual(result, Self.validJPEG)
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://gateway.example/v1/ai/garment-cleanup")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertNil(capturedRequest?.value(forHTTPHeaderField: "Idempotency-Key"))
        XCTAssertTrue(capturedRequest?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=Pyxis-") == true)
    }

    func testRejectsImageMimeWithInvalidSignature() async throws {
        let imageURL = try makeSourceImage()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"]
            )!
            return (response, Data("not an image".utf8))
        }

        do {
            _ = try await makeService().makePristineGarment(from: imageURL)
            XCTFail("Expected invalid response")
        } catch let error as AIGarmentStudioError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRejectsUnsupportedSuccessfulMimeType() async throws {
        let imageURL = try makeSourceImage()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (response, Self.validJPEG)
        }

        do {
            _ = try await makeService().makePristineGarment(from: imageURL)
            XCTFail("Expected invalid response")
        } catch let error as AIGarmentStudioError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRejectsMalformedOrOversizedContentLength() async throws {
        let imageURL = try makeSourceImage()
        for contentLength in ["not-a-number", "-1", "999999999"] {
            URLProtocolStub.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "image/jpeg",
                        "Content-Length": contentLength
                    ]
                )!
                return (response, Self.validJPEG)
            }

            do {
                _ = try await makeService().makePristineGarment(from: imageURL)
                XCTFail("Expected invalid response for Content-Length \(contentLength)")
            } catch let error as AIGarmentStudioError {
                XCTAssertEqual(error, .invalidResponse)
            }
        }
    }

    func testRejectsOversizedResponseWithoutContentLength() async throws {
        let imageURL = try makeSourceImage()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"])!
            return (response, Self.validJPEG + Data(repeating: 0, count: 20 * 1_024 * 1_024))
        }
        do {
            _ = try await makeService().makePristineGarment(from: imageURL)
            XCTFail("Expected bounded transfer failure")
        } catch let error as AIGarmentStudioError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRejectsOversizedErrorBeforeDecodingServerMessage() async throws {
        let imageURL = try makeSourceImage()
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil,
                headerFields: ["Content-Type": "application/json", "Content-Length": "999999999"])!
            return (response, Data("{\"error\":\"provider details\"}".utf8))
        }
        do {
            _ = try await makeService().makePristineGarment(from: imageURL)
            XCTFail("Expected bounded error response")
        } catch let error as AIGarmentStudioError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRedirectDelegateNeverRepostsSelectedPhotos() {
        let original = URL(string: "https://gateway.example/v1/ai/garment-cleanup")!
        let response = HTTPURLResponse(url: original, statusCode: 307, httpVersion: nil,
            headerFields: ["Location": "https://other.example/collect"])!
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: original)
        var callbackInvoked = false
        AITransferDelegate().urlSession(session, task: task, willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: URL(string: "https://other.example/collect")!)) { redirected in
            callbackInvoked = true
            XCTAssertNil(redirected)
        }
        XCTAssertTrue(callbackInvoked)
    }

    func testRejectsUnsafeGatewayConfigurationAndEmptyTokens() {
        for address in ["http://gateway.example", "https://user:pass@gateway.example", "https://gateway.example?token=example", "https://gateway.example#fragment"] {
            let service = AIGarmentStudioService(baseURL: URL(string: address), accessToken: "test-token")
            XCTAssertFalse(service.isConfigured)
        }
        XCTAssertFalse(AIGarmentStudioService(baseURL: URL(string: "https://gateway.example"), accessToken: " ").isConfigured)
    }

    func testRejectsTooManyGarmentsBeforeUpload() async throws {
        let imageURL = try makeSourceImage()
        URLProtocolStub.requestHandler = { _ in
            XCTFail("Unexpected upload")
            throw URLError(.badURL)
        }
        do {
            _ = try await makeService().makeTryOn(personURL: imageURL, garmentURLs: Array(repeating: imageURL, count: 7))
            XCTFail("Expected garment count validation")
        } catch let error as AIGarmentStudioError {
            XCTAssertEqual(error, .invalidImage)
        }
    }

    private func makeService() -> AIGarmentStudioService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return AIGarmentStudioService(
            baseURL: URL(string: "https://gateway.example"),
            accessToken: "test-token",
            session: URLSession(configuration: configuration)
        )
    }

    private func makeSourceImage() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-AI-test-\(UUID().uuidString).jpg")
        let data = try XCTUnwrap(makeTestImage().jpegDataForTests())
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private static let validJPEG = Data([0xFF, 0xD8, 0xFF, 0xD9])

    private static func imageResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/jpeg"]
        )!
        return (response, validJPEG)
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
