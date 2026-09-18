import Foundation

public extension FileManager {
    func pyxisApplicationSupportDirectory() throws -> URL {
        let baseURL = try url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseURL.appendingPathComponent("Pyxis", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        try createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
