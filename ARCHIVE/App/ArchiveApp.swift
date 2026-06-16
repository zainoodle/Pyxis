import SwiftData
import SwiftUI

@main
struct ArchiveApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try SwiftDataContainer.makeAppContainer()
        } catch {
            fatalError("Failed to create ARCHIVE model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ClosetGridView()
        }
        .modelContainer(modelContainer)
    }
}
