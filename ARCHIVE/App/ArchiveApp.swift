import ArchiveCore
import AppKit
import SwiftData
import SwiftUI

@main
struct ArchiveApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            NSApplication.shared.setActivationPolicy(.regular)
            modelContainer = try SwiftDataContainer.makeAppContainer()
        } catch {
            fatalError("Failed to create ARCHIVE model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ClosetGridView()
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .modelContainer(modelContainer)
    }
}
