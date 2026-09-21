import Foundation
import ImageIO

public protocol TryOnProviding: Sendable {
    var isConfigured: Bool { get }
    func configuration() async throws -> TryOnConfiguration
    func allowance(authorization: String) async throws -> TryOnAllowance
    func generate(person: URL, garments: [TryOnGarment], authorization: String, consent: String, jobID: UUID) async throws -> TryOnResult
}

public final class TryOnService: TryOnProviding, @unchecked Sendable {
    public static var configuredBaseURL: URL? {
        #if DEBUG
        if let value = Bundle.main.object(forInfoDictionaryKey: "PYXIS_PC_BASE_URL") as? String,
           !value.isEmpty, !value.contains("$(") { return URL(string: value) }
        #endif
        return AIGarmentStudioService.configuredBaseURL
    }
    private let baseURL: URL?
    private let session: URLSession
    public var isConfigured: Bool { baseURL != nil }
    public init(baseURL: URL? = TryOnService.configuredBaseURL, session: URLSession? = nil) {
        self.baseURL = baseURL.flatMap {
            $0.scheme == "https" && $0.host != nil && $0.user == nil && $0.password == nil && $0.query == nil && $0.fragment == nil ? $0 : nil
        }
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpShouldSetCookies = false
        config.timeoutIntervalForResource = 600
        self.session = session ?? URLSession(configuration: config)
    }
    public func configuration() async throws -> TryOnConfiguration {
        let (data, _) = try await transfer(request("config"), maximum: 64000)
        let config = try JSONDecoder().decode(TryOnConfiguration.self, from: data)
        guard config.supportsPrivacyContract, (1...100).contains(config.limit) else { throw TryOnError.unavailable }
        if config.isPrivatePC {
            guard baseURL?.host?.hasSuffix(".ts.net") == true,
                  let counts = config.supportedGarmentCounts, !counts.isEmpty,
                  counts.allSatisfy({ (1...6).contains($0) }) else { throw TryOnError.unavailable }
        }
        return config
    }
    public func allowance(authorization: String) async throws -> TryOnAllowance {
        var req = try request("usage")
        req.setValue(authorization, forHTTPHeaderField: "Authorization")
        let (data, _) = try await transfer(req, maximum: 64000)
        let allowance = try JSONDecoder().decode(TryOnAllowance.self, from: data)
        guard (1...100).contains(allowance.limit), allowance.renewsAt.isFinite, allowance.renewsAt > 0,
              allowance.remaining >= 0, allowance.remaining <= allowance.limit else { throw TryOnError.invalidResponse }
        return allowance
    }
    public func generate(person: URL, garments: [TryOnGarment], authorization: String, consent: String, jobID: UUID) async throws -> TryOnResult {
        var validConsent = consent == TryOnPrivacy.version
        #if DEBUG
        if consent == TryOnPrivacy.pcVersion {
            // Fetch the current contract before reading/uploading photos. A provider switch requires fresh consent.
            let config = try await configuration()
            validConsent = config.isPrivatePC && config.available && config.supportedGarmentCounts?.contains(garments.count) == true && authorization.hasPrefix("Test ")
        }
        #endif
        guard validConsent else { throw TryOnError.consentRequired }
        #if DEBUG
        if baseURL?.host?.hasSuffix(".ts.net") == true && consent != TryOnPrivacy.pcVersion {
            // Never transmit under an old xAI disclosure to the private PC endpoint.
            throw TryOnError.consentRequired
        }
        #endif
        guard !garments.isEmpty, garments.count <= 6 else { throw TryOnError.invalidImage }
        let boundary = "Pyxis-\(UUID().uuidString)"
        var req = try request("generate")
        req.httpMethod = "POST"; req.timeoutInterval = 600
        req.setValue(authorization, forHTTPHeaderField: "Authorization")
        req.setValue(consent, forHTTPHeaderField: "X-Pyxis-Consent")
        req.setValue(jobID.uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = try await Task.detached(priority: .userInitiated) {
            var body = Data()
            let images = [("person", person)] + garments.enumerated().map { ("garment_\($0.offset + 1)", $0.element.imageURL) }
            for (name, url) in images {
                let data = try ImageUtilities.aiUploadJPEGData(from: url)
                guard data.count <= 4 * 1024 * 1024 else { throw TryOnError.invalidImage }
                body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(name).jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
                body.append(data); body.append(Data("\r\n".utf8))
            }
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"categories\"\r\n\r\n".utf8))
            body.append(try JSONEncoder().encode(garments.map(\.category.rawValue)))
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            return body
        }.value
        let (data, response) = try await transfer(req, maximum: 20 * 1024 * 1024)
        guard let type = response.value(forHTTPHeaderField: "Content-Type"), type.hasPrefix("image/"),
              let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 32] as CFDictionary) != nil,
              let remaining = response.value(forHTTPHeaderField: "X-Pyxis-Remaining").flatMap(Int.init),
              let limit = response.value(forHTTPHeaderField: "X-Pyxis-Limit").flatMap(Int.init),
              let renewal = response.value(forHTTPHeaderField: "X-Pyxis-Renews-At").flatMap(Double.init),
              (1...100).contains(limit), renewal.isFinite, renewal > 0, remaining >= 0, remaining <= limit else { throw TryOnError.invalidResponse }
        return TryOnResult(imageData: data, allowance: TryOnAllowance(limit: limit, remaining: remaining, renewsAt: renewal))
    }
    private func request(_ path: String) throws -> URLRequest {
        guard let baseURL else { throw TryOnError.unavailable }
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/try-on/\(path)"))
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30
        return request
    }
    private func transfer(_ request: URLRequest, maximum: Int) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request, delegate: AITransferDelegate())
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse else { throw TryOnError.invalidResponse }
        if let header = http.value(forHTTPHeaderField: "Content-Length") {
            guard let count = Int(header), count >= 0, count <= maximum else { throw TryOnError.invalidResponse }
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximum else { throw TryOnError.invalidResponse }
            data.append(byte)
        }
        guard (200..<300).contains(http.statusCode) else {
            let failure = try? JSONDecoder().decode(ServerError.self, from: data)
            if failure?.code == "pc_job_unrecoverable" { throw TryOnError.pcJobUnrecoverable }
            if failure?.code == "already_generated" { throw TryOnError.alreadyGenerated }
            throw TryOnError.server(failure?.error ?? "Try-on could not finish. Please try again.")
        }
        return (data, http)
    }
    private struct ServerError: Decodable { let error: String; let code: String? }
}
