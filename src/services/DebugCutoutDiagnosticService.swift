#if DEBUG
import Foundation

/// Opt-in hardware QA against a stored original, isolated from the user's wardrobe records.
enum DebugCutoutDiagnosticService {
    static func runIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-pyxis.cutoutDiagnostic"),
              arguments.indices.contains(flag + 1),
              arguments[flag + 1].hasPrefix("Images/Originals/") else { return }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Pyxis-CutoutDiagnostic", isDirectory: true)
        do {
            let sourceStorage = try ImageStorageService()
            let scratchStorage = try ImageStorageService(rootURL: root)
            let statusURL = root.appendingPathComponent("result.json")
            try JSONSerialization.data(withJSONObject: ["status": "running"]).write(to: statusURL, options: .atomic)
            let start = Date()
            let result = await LocalBackgroundRemovalService(imageStorage: scratchStorage).processImage(
                at: sourceStorage.url(for: arguments[flag + 1]), itemID: UUID()
            )
            let report: [String: Any] = [
                "status": result.status == .succeeded ? "succeeded" : "failed",
                "seconds": Date().timeIntervalSince(start),
                "cutoutPath": result.cutoutPath ?? "",
                "error": result.errorMessage ?? ""
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: statusURL, options: .atomic)
        } catch {
            // Diagnostics must never interrupt ordinary app startup.
        }
    }
}
#endif
