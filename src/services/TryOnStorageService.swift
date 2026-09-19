import Foundation
import ImageIO

/// Additive, versioned storage. Existing closet/SwiftData records are never changed.
public final class TryOnStorageService: @unchecked Sendable {
    private static let processSession = UUID().uuidString
    public let rootURL: URL
    public let sessionURL: URL
    private let files = FileManager.default
    public init(rootURL: URL? = nil) throws {
        self.rootURL = try rootURL ?? FileManager.default.pyxisApplicationSupportDirectory().appendingPathComponent("TryOn", isDirectory: true)
        sessionURL = self.rootURL.appendingPathComponent("Sessions/\(Self.processSession)/\(UUID().uuidString)", isDirectory: true)
        try prepare(self.rootURL)
        // Unsaved photos from an interrupted prior launch must not accumulate.
        let sessions = self.rootURL.appendingPathComponent("Sessions", isDirectory: true)
        if files.fileExists(atPath: sessions.path) {
            for abandoned in try files.contentsOfDirectory(at: sessions, includingPropertiesForKeys: nil)
                where abandoned.lastPathComponent != Self.processSession {
                try files.removeItem(at: abandoned)
            }
        }
        try prepare(sessionURL)
        try prepare(self.rootURL.appendingPathComponent("Saved", isDirectory: true))
    }
    public var savedReferenceURL: URL? {
        let url = rootURL.appendingPathComponent("reference.jpg")
        return files.fileExists(atPath: url.path) ? url : nil
    }
    public func importPhoto(_ data: Data) throws -> URL {
        guard data.count <= 40 * 1024 * 1024 else { throw TryOnError.invalidImage }
        let raw = sessionURL.appendingPathComponent("\(UUID().uuidString).source")
        try write(data, to: raw)
        defer { try? files.removeItem(at: raw) }
        let jpeg = try ImageUtilities.aiUploadJPEGData(from: raw)
        guard jpeg.count <= 4 * 1024 * 1024 else { throw TryOnError.invalidImage }
        let url = sessionURL.appendingPathComponent("\(UUID().uuidString).jpg")
        try write(jpeg, to: url)
        return url
    }
    public func rememberReference(_ url: URL) throws {
        try write(Data(contentsOf: url), to: rootURL.appendingPathComponent("reference.jpg"))
    }
    public func forgetReference() throws {
        if let url = savedReferenceURL { try files.removeItem(at: url) }
    }
    public func storeGenerated(_ data: Data) throws -> URL { try importPhoto(data) }
    public func savePreview(at url: URL, names: [String], id: UUID) throws -> SavedTryOn {
        var manifest = try readManifest()
        if let existing = manifest.previews.first(where: { $0.id == id }) { return existing }
        let preview = SavedTryOn(id: id, createdAt: Date(), garmentNames: names)
        let destination = imageURL(for: preview)
        try write(Data(contentsOf: url), to: destination)
        manifest.previews.insert(preview, at: 0)
        do { try write(JSONEncoder().encode(manifest), to: rootURL.appendingPathComponent("manifest.json")) }
        catch { try? files.removeItem(at: destination); throw error }
        return preview
    }
    public func previews() throws -> [SavedTryOn] { try readManifest().previews }
    public func imageURL(for preview: SavedTryOn) -> URL {
        rootURL.appendingPathComponent("Saved").appendingPathComponent(preview.filename)
    }
    public func delete(_ preview: SavedTryOn) throws {
        var manifest = try readManifest()
        // Remove the image first; never claim deletion while sensitive image bytes remain.
        let url = imageURL(for: preview)
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
        manifest.previews.removeAll { $0.id == preview.id }
        try write(JSONEncoder().encode(manifest), to: rootURL.appendingPathComponent("manifest.json"))
    }
    public func endSession() { try? files.removeItem(at: sessionURL) }
    private func readManifest() throws -> Manifest {
        let url = rootURL.appendingPathComponent("manifest.json")
        guard files.fileExists(atPath: url.path) else { return Manifest() }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
        guard manifest.version == 1 else { throw TryOnError.storageVersion }
        return manifest
    }
    private func prepare(_ url: URL) throws {
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        var local = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try local.setResourceValues(values)
        #if os(iOS)
        try files.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
    private struct Manifest: Codable { var version = 1; var previews: [SavedTryOn] = [] }
}
