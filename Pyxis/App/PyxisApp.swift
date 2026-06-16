import SwiftData
import SwiftUI

@main
struct PyxisApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try SwiftDataContainer.makeAppContainer()
        } catch {
            fatalError("Failed to create Pyxis model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ClosetGridView()
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
