import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AIGarmentStudioError: LocalizedError, Equatable {
    case notConfigured
    case invalidResponse
    case server(String)
    case invalidImage

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI Studio is not configured yet."
        case .invalidResponse:
            return "AI Studio returned an unreadable image."
        case .server(let message):
            return message
        case .invalidImage:
            return "One of the selected images could not be read."
        }
    }
}

public protocol AIGarmentStudioProviding: Sendable {
    var isConfigured: Bool { get }
    func makePristineGarment(from imageURL: URL) async throws -> Data
    func makeTryOn(personURL: URL, garmentURLs: [URL]) async throws -> Data
}

public extension AIGarmentStudioProviding {
    var isConfigured: Bool { true }
}

/// Talks only to the app owner's authenticated backend. Provider API keys must
/// never be included in the iOS app. Set the Pyxis endpoint and scoped access
/// token through build settings rather than hard-coding either value.
public final class AIGarmentStudioService: AIGarmentStudioProviding, @unchecked Sendable {
    private let baseURL: URL?
    private let accessToken: String?
    private let session: URLSession
    private static let maximumResponseBytes = 20 * 1_024 * 1_024
    private static let maximumRequestBytes = 48 * 1_024 * 1_024

    public init(
        baseURL: URL? = AIGarmentStudioService.configuredBaseURL,
        accessToken: String? = AIGarmentStudioService.configuredAccessToken,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.session = session ?? Self.makeEphemeralSession()
    }

    public var isConfigured: Bool {
        baseURL != nil && accessToken != nil
    }

    public static var isConfigured: Bool {
        configuredBaseURL != nil && configuredAccessToken != nil
    }

    public func makePristineGarment(from imageURL: URL) async throws -> Data {
        try await generate(
            path: "v1/ai/garment-cleanup",
            images: [("source", imageURL)]
        )
    }

    public func makeTryOn(personURL: URL, garmentURLs: [URL]) async throws -> Data {
        guard !garmentURLs.isEmpty else { throw AIGarmentStudioError.invalidImage }
        let images = [("person", personURL)] + garmentURLs.enumerated().map { index, url in
            ("garment_\(index + 1)", url)
        }
        return try await generate(path: "v1/ai/virtual-try-on", images: images)
    }

    public static var configuredBaseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PYXIS_AI_BASE_URL") as? String else {
            return nil
        }
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil else {
            return nil
        }
        return url
    }

    public static var configuredAccessToken: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PYXIS_AI_ACCESS_TOKEN") as? String else {
            return nil
        }
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    private func generate(path: String, images: [(String, URL)]) async throws -> Data {
        guard let baseURL, let accessToken else { throw AIGarmentStudioError.notConfigured }
        let boundary = "Pyxis-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.multipartBody(images: images, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIGarmentStudioError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw AIGarmentStudioError.server(payload?.error ?? "AI generation failed. Try again.")
        }
        guard !data.isEmpty, data.count <= Self.maximumResponseBytes else {
            throw AIGarmentStudioError.invalidResponse
        }

        if let contentLength = http.value(forHTTPHeaderField: "Content-Length") {
            guard let length = Int(contentLength), length >= 0, length <= Self.maximumResponseBytes else {
                throw AIGarmentStudioError.invalidResponse
            }
        }

        if http.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true {
            guard let payload = try? JSONDecoder().decode(ImageEnvelope.self, from: data),
                  payload.imageBase64.utf8.count <= Self.maximumResponseBytes * 4 / 3 + 16,
                  let decoded = Data(base64Encoded: payload.imageBase64),
                  Self.isSupportedImage(decoded) else {
                throw AIGarmentStudioError.invalidResponse
            }
            return decoded
        }

        guard let mimeType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
              ["image/jpeg", "image/png", "image/webp"].contains(where: mimeType.hasPrefix),
              Self.isSupportedImage(data) else {
            throw AIGarmentStudioError.invalidResponse
        }
        return data
    }

    private static func multipartBody(images: [(String, URL)], boundary: String) throws -> Data {
        var body = Data()
        for (name, url) in images {
            guard let data = try? ImageUtilities.aiUploadJPEGData(from: url), !data.isEmpty else {
                throw AIGarmentStudioError.invalidImage
            }
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(name).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.append("\r\n")
            guard body.count <= maximumRequestBytes else {
                throw AIGarmentStudioError.invalidImage
            }
        }
        body.append("--\(boundary)--\r\n")
        guard body.count <= maximumRequestBytes else {
            throw AIGarmentStudioError.invalidImage
        }
        return body
    }

    private static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 150
        return URLSession(configuration: configuration)
    }

    private static func isSupportedImage(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 3, bytes[0...2].elementsEqual([0xFF, 0xD8, 0xFF]) {
            return true
        }
        if bytes.count >= 8, bytes[0...7].elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return true
        }
        if bytes.count >= 12,
           bytes[0...3].elementsEqual(Array("RIFF".utf8)),
           bytes[8...11].elementsEqual(Array("WEBP".utf8)) {
            return true
        }
        return false
    }
}

private struct ImageEnvelope: Decodable {
    let imageBase64: String

    enum CodingKeys: String, CodingKey { case imageBase64 = "image_base64" }
}

private struct ErrorEnvelope: Decodable { let error: String }

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
