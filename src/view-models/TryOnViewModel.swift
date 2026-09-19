import Foundation
import Combine

@MainActor
final class TryOnViewModel: ObservableObject {
    @Published var garments: [TryOnGarment]
    @Published private(set) var personURL: URL?
    @Published private(set) var generatedURL: URL?
    @Published private(set) var previews: [SavedTryOn] = []
    @Published private(set) var configuration: TryOnConfiguration?
    @Published private(set) var allowance: TryOnAllowance?
    @Published private(set) var isGenerating = false
    @Published private(set) var isImporting = false
    @Published private(set) var isLoading = false
    @Published private(set) var rememberPhoto = false
    @Published private(set) var hasConsent = false
    @Published private(set) var resultSaved = false
    @Published var errorMessage: String?
    @Published var showsOriginal = false
    private let service: any TryOnProviding
    private let storage: TryOnStorageService?
    private let preferences: UserDefaults
    private var resultID = UUID()
    private var resultNames: [String] = []
    private var generationID = UUID()
    private static let consentKey = "tryOn.photoProcessingConsent"

    init(garments: [TryOnGarment] = [], service: any TryOnProviding = TryOnService(), storage: TryOnStorageService? = try? TryOnStorageService(), preferences: UserDefaults = .standard) {
        self.garments = garments; self.service = service; self.storage = storage; self.preferences = preferences
        personURL = storage?.savedReferenceURL
        rememberPhoto = personURL != nil
        hasConsent = preferences.string(forKey: Self.consentKey) == TryOnPrivacy.version
        do { previews = try storage?.previews() ?? [] }
        catch { errorMessage = error.localizedDescription }
    }
    deinit { storage?.endSession() }
    var canGenerate: Bool {
        configuration?.available == true && personURL != nil && !garments.isEmpty && garments.count <= 6 &&
        !isGenerating && !isImporting && (allowance?.remaining ?? 0) > 0
    }
    var available: Bool { configuration?.available == true }
    func load() async {
        guard service.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do { configuration = try await service.configuration() }
        catch { errorMessage = error.localizedDescription }
    }
    func refreshAllowance(authorization: String?) async {
        guard available, let authorization else { allowance = nil; return }
        do { allowance = try await service.allowance(authorization: authorization) }
        catch { allowance = nil; errorMessage = error.localizedDescription }
    }
    func acceptConsent() {
        preferences.set(TryOnPrivacy.version, forKey: Self.consentKey); hasConsent = true
    }
    func revokeConsent() {
        preferences.removeObject(forKey: Self.consentKey); hasConsent = false
    }
    func importPhoto(_ data: Data, forPerson: Bool) async {
        guard !isGenerating, !isImporting, let storage else { return }
        isImporting = true; errorMessage = nil
        defer { isImporting = false }
        do {
            let url = try await Task.detached(priority: .userInitiated) { try storage.importPhoto(data) }.value
            if forPerson {
                if rememberPhoto { try storage.rememberReference(url) }
                personURL = url
            } else {
                guard garments.count < 6 else { throw TryOnError.server("Choose up to six pieces for one preview.") }
                let classification = await Task.detached(priority: .userInitiated) {
                    ClothingClassificationService().classify(imageURL: url, filename: nil)
                }.value
                garments.append(TryOnGarment(imageURL: url, category: classification.category, name: "Added photo"))
            }
            selectionChanged()
        } catch { errorMessage = error.localizedDescription }
    }
    func setRememberPhoto(_ remember: Bool) {
        do {
            if remember, let personURL { try storage?.rememberReference(personURL) }
            if !remember {
                // Keep a session copy so toggling off does not invalidate the current input.
                if let personURL, personURL == storage?.savedReferenceURL {
                    self.personURL = try storage?.importPhoto(Data(contentsOf: personURL))
                }
                try storage?.forgetReference()
            }
            rememberPhoto = remember
        } catch { errorMessage = error.localizedDescription }
    }
    func removeReference() {
        do {
            try storage?.forgetReference()
            if let personURL, personURL.path.hasPrefix((storage?.sessionURL.path ?? "") + "/") {
                try FileManager.default.removeItem(at: personURL)
            }
            personURL = nil; rememberPhoto = false; selectionChanged()
        } catch { errorMessage = error.localizedDescription }
    }
    func selectionChanged() {
        generatedURL = nil; showsOriginal = false; resultSaved = false; generationID = UUID()
    }
    func generate(authorization: String?) async {
        guard !isGenerating else { return }
        guard hasConsent else { errorMessage = TryOnError.consentRequired.localizedDescription; return }
        guard let authorization else { errorMessage = TryOnError.purchaseRequired.localizedDescription; return }
        guard canGenerate, let personURL, let storage else { return }
        isGenerating = true; errorMessage = nil
        defer { isGenerating = false }
        let selected = garments
        do {
            let result = try await service.generate(person: personURL, garments: selected, authorization: authorization,
                consent: TryOnPrivacy.version, jobID: generationID)
            allowance = result.allowance
            generatedURL = try await Task.detached(priority: .userInitiated) { try storage.storeGenerated(result.imageData) }.value
            resultID = generationID; resultNames = selected.map(\.name)
            resultSaved = false; showsOriginal = false
            generationID = UUID() // A deliberate new variation is a new charge.
        } catch {
            errorMessage = error.localizedDescription
            if error as? TryOnError == .alreadyGenerated {
                // The server confirmed completion after its in-memory replay expired.
                // A future deliberate tap starts a new preview; never silently regenerate.
                generationID = UUID()
            }
            // Keep other failed job IDs for transport retries to prevent duplicate charges.
            await refreshAllowance(authorization: authorization)
        }
    }
    func saveResult() {
        guard let generatedURL, let storage else { return }
        do {
            _ = try storage.savePreview(at: generatedURL, names: resultNames, id: resultID)
            previews = try storage.previews(); resultSaved = true
        } catch { errorMessage = error.localizedDescription }
    }
    func deletePreview(_ preview: SavedTryOn) {
        do {
            try storage?.delete(preview); previews = try storage?.previews() ?? []
            if preview.id == resultID { resultSaved = false }
        } catch { errorMessage = error.localizedDescription }
    }
    func previewURL(_ preview: SavedTryOn) -> URL? { storage?.imageURL(for: preview) }
}
