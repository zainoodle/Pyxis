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
        self.rootURL = try rootURL ?? fileManager.pyxisApplicationSupportDirectory()
        try createDirectories()
    }

    public func createDirectories() throws {
        try fileManager.ensureDirectoryExists(at: originalsURL)
        try fileManager.ensureDirectoryExists(at: cutoutsURL)
        try fileManager.ensureDirectoryExists(at: thumbnailsURL)
    }

    public func saveOriginal(from sourceURL: URL, itemID: UUID) throws -> String {
        let destination = originalsURL.appendingPathComponent("\(itemID.uuidString).\(sourceURL.safeImagePathExtensionOrDefault)")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        let didStartSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
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
        safeURL(for: relativePath) ?? invalidImageURL
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
        let rootPath = normalizedPath(rootURL)
        let path = normalizedPath(url)
        guard isPath(path, nestedIn: rootPath) else {
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

        guard let fileURL = safeURL(for: relativePath) else {
            return
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private var invalidImageURL: URL {
        imagesURL.appendingPathComponent("__invalid_image_path__")
    }

    private func safeURL(for relativePath: String) -> URL? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !trimmed.contains("\\") else {
            return nil
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        let candidate = components.reduce(rootURL) { partialURL, component in
            partialURL.appendingPathComponent(String(component))
        }

        let rootPath = normalizedPath(rootURL)
        let candidatePath = normalizedPath(candidate)
        return isPath(candidatePath, nestedIn: rootPath) ? candidate : nil
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func isPath(_ path: String, nestedIn rootPath: String) -> Bool {
        path == rootPath || path.hasPrefix(rootPath + "/")
    }
}

private extension URL {
    var safeImagePathExtensionOrDefault: String {
        let allowedExtensions: Set<String> = [
            "jpg",
            "jpeg",
            "png",
            "heic",
            "heif",
            "webp",
            "gif",
            "tif",
            "tiff",
            "bmp"
        ]
        let value = pathExtension.lowercased().filter { $0.isLetter || $0.isNumber }
        return allowedExtensions.contains(value) ? value : "jpg"
    }
}
