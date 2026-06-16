import Foundation

public struct StoredImageSet: Equatable, Sendable {
    public var originalPath: String
    public var cutoutPath: String?
    public var thumbnailPath: String?

    public init(originalPath: String, cutoutPath: String? = nil, thumbnailPath: String? = nil) {
        self.originalPath = originalPath
        self.cutoutPath = cutoutPath
        self.thumbnailPath = thumbnailPath
    }
}

public final class ImageStorageService {
    public let rootURL: URL
    private let fileManager: FileManager

    public var imagesURL: URL {
        rootURL.appendingPathComponent("Images", isDirectory: true)
    }

    public var originalsURL: URL {
        imagesURL.appendingPathComponent("Originals", isDirectory: true)
    }

    public var cutoutsURL: URL {
        imagesURL.appendingPathComponent("Cutouts", isDirectory: true)
    }

    public var thumbnailsURL: URL {
        imagesURL.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.rootURL = try rootURL ?? fileManager.archiveApplicationSupportDirectory()
        try createDirectories()
    }

    public func createDirectories() throws {
        try fileManager.ensureDirectoryExists(at: originalsURL)
        try fileManager.ensureDirectoryExists(at: cutoutsURL)
        try fileManager.ensureDirectoryExists(at: thumbnailsURL)
    }

    public func saveOriginal(from sourceURL: URL, itemID: UUID) throws -> String {
        let destination = originalsURL.appendingPathComponent("\(itemID.uuidString).\(sourceURL.pathExtensionOrDefault)")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return relativePath(for: destination)
    }

    public func saveCutoutPNG(_ data: Data, itemID: UUID) throws -> String {
        let destination = cutoutsURL.appendingPathComponent("\(itemID.uuidString).png")
        try data.write(to: destination, options: .atomic)
        return relativePath(for: destination)
    }

    public func saveThumbnailPNG(_ data: Data, itemID: UUID) throws -> String {
        let destination = thumbnailsURL.appendingPathComponent("\(itemID.uuidString).png")
        try data.write(to: destination, options: .atomic)
        return relativePath(for: destination)
    }

    public func makeThumbnail(from imageURL: URL, itemID: UUID) throws -> String {
        let data = try ImageUtilities.thumbnailPNGData(from: imageURL)
        return try saveThumbnailPNG(data, itemID: itemID)
    }

    public func url(for relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }

    public func deleteImages(for item: ClosetItem) {
        deleteIfPresent(item.imageOriginalPath)
        deleteIfPresent(item.imageCutoutPath)
        deleteIfPresent(item.thumbnailPath)
    }

    public func deleteImages(_ imageSet: StoredImageSet) {
        deleteIfPresent(imageSet.originalPath)
        deleteIfPresent(imageSet.cutoutPath)
        deleteIfPresent(imageSet.thumbnailPath)
    }

    public func relativePath(for url: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }

        let suffix = String(path.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
        return suffix.replacingOccurrences(of: "\\", with: "/")
    }

    private func deleteIfPresent(_ relativePath: String?) {
        guard let relativePath, !relativePath.isEmpty else {
            return
        }

        let fileURL = url(for: relativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

private extension URL {
    var pathExtensionOrDefault: String {
        let value = pathExtension.lowercased()
        return value.isEmpty ? "jpg" : value
    }
}
