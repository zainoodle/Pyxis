import Combine
import Foundation

/// Checks access without asking for, reading, or uploading a reference photo.
@MainActor
final class TryOnEntryViewModel: ObservableObject {
    @Published private(set) var destination: TryOnEntry?
    private let service: any TryOnProviding
    private let storage: TryOnStorageService?

    init(service: any TryOnProviding = TryOnService(), storage: TryOnStorageService? = try? TryOnStorageService()) {
        self.service = service
        self.storage = storage
    }

    deinit { storage?.endSession() }

    func load() async {
        let hasSaved: Bool
        do { hasSaved = !(try storage?.previews() ?? []).isEmpty }
        catch { hasSaved = true } // Keep the gallery's recovery message reachable.
        destination = hasSaved ? .savedPreviews : nil
        guard service.isConfigured else { return }
        do {
            let config = try await service.configuration()
            if config.available { destination = .generate }
        } catch { /* Wardrobe tasks remain available while try-on is offline. */ }
    }
}

enum TryOnEntry: String, Identifiable {
    case generate, savedPreviews
    var id: String { rawValue }
    var title: String { self == .generate ? "Try on" : "Saved previews" }
}
