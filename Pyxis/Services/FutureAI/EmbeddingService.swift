import Foundation

public struct EmbeddingInput: Sendable {
    public let imageURL: URL?
    public let text: String?

    public init(imageURL: URL? = nil, text: String? = nil) {
        self.imageURL = imageURL
        self.text = text
    }
}

public protocol EmbeddingService {
    func embedding(for input: EmbeddingInput) async throws -> [Double]
}
