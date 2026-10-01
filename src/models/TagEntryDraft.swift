import Foundation

/// Keeps an unfinished tag in the value saved by the surrounding form.
public struct TagEntryDraft: Equatable {
    public private(set) var tags: [String]
    public private(set) var input = ""

    public init(text: String) { tags = Self.parse(text) }
    public var text: String { (tags + Self.parse(input)).joined(separator: ", ") }

    public mutating func updateInput(_ value: String) { input = value }

    public mutating func commitInput() {
        tags.append(contentsOf: Self.parse(input))
        input = ""
    }

    public mutating func remove(at index: Int) {
        guard tags.indices.contains(index) else { return }
        tags.remove(at: index)
    }

    private static func parse(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
