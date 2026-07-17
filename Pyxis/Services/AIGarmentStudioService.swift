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
    func makePristineGarment(from imageURL: URL) async throws -> Data
    func makeTryOn(personURL: URL, garmentURLs: [URL]) async throws -> Data
}

/// Talks only to the app owner's authenticated backend. The OpenAI API key must
/// never be included in the iOS app. Set `PYXIS_AI_BASE_URL` in Info.plist.
public final class AIGarmentStudioService: AIGarmentStudioProviding, @unchecked Sendable {
    private let baseURL: URL?
    private let session: URLSession

    public init(
        baseURL: URL? = AIGarmentStudioService.configuredBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
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

    private func generate(path: String, images: [(String, URL)]) async throws -> Data {
        guard let baseURL else { throw AIGarmentStudioError.notConfigured }
        let boundary = "Pyxis-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try Self.multipartBody(images: images, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIGarmentStudioError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw AIGarmentStudioError.server(payload?.error ?? "AI generation failed. Try again.")
        }
        guard !data.isEmpty else { throw AIGarmentStudioError.invalidResponse }

        if http.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true {
            guard let payload = try? JSONDecoder().decode(ImageEnvelope.self, from: data),
                  let decoded = Data(base64Encoded: payload.imageBase64), !decoded.isEmpty else {
                throw AIGarmentStudioError.invalidResponse
            }
            return decoded
        }
        return data
    }

    private static func multipartBody(images: [(String, URL)], boundary: String) throws -> Data {
        var body = Data()
        for (name, url) in images {
            guard let data = try? Data(contentsOf: url), !data.isEmpty else {
                throw AIGarmentStudioError.invalidImage
            }
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(name).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
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
