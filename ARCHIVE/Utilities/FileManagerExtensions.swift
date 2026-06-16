import Foundation

public extension FileManager {
    func archiveApplicationSupportDirectory() throws -> URL {
        let baseURL = try url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseURL.appendingPathComponent("ARCHIVE", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        try createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
