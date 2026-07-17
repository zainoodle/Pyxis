import PhotosUI
import SwiftUI

struct AITryOnView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [ClosetItem]

    @State private var personSelection: PhotosPickerItem?
    @State private var personURL: URL?
    @State private var generatedURL: URL?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    private let service: any AIGarmentStudioProviding = AIGarmentStudioService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PyxisSpacing.lg) {
                    if let generatedURL {
                        LocalImageView(url: generatedURL)
                            .frame(maxWidth: 420)
                            .frame(height: 520)
                            .accessibilityLabel("Generated AI try-on preview")
                    } else if let personURL {
                        LocalImageView(url: personURL)
                            .frame(maxWidth: 420)
                            .frame(height: 420)
                            .accessibilityLabel("Your selected person photo")
                    } else {
                        VStack(spacing: PyxisSpacing.md) {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 44, weight: .light))
                            Text("ADD A FULL-BODY PHOTO")
                                .font(PyxisTypography.body)
                            Text("FACE FORWARD, EVEN LIGHT, ARMS SLIGHTLY AWAY FROM YOUR BODY")
                                .font(PyxisTypography.label)
                                .foregroundStyle(PyxisColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .background(PyxisColors.field)
                    }

                    PhotosPicker(selection: $personSelection, matching: .images) {
                        Text(personURL == nil ? "CHOOSE YOUR PHOTO" : "CHANGE PHOTO")
                    }
                    .buttonStyle(MinimalButtonStyle())

                    Button(isGenerating ? "GENERATING TRY-ON" : "GENERATE AI TRY-ON") {
                        Task { await generate() }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(personURL == nil || items.isEmpty || isGenerating)

                    Text("YOUR PHOTO AND SELECTED CLOTHING ARE SENT TO XAI FOR GENERATION. XAI MAY RETAIN API DATA FOR UP TO 30 DAYS. THIS IS A VISUAL PREVIEW, NOT A SIZE OR FIT GUARANTEE.")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.inactiveText)
                        .multilineTextAlignment(.center)

                    if let errorMessage { InlineErrorMessage(message: errorMessage) }
                }
                .padding(PyxisSpacing.md)
            }
            .background(PyxisColors.background)
            .navigationTitle("AI TRY-ON")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("CLOSE") { dismiss() }
                }
            }
            .task(id: personSelection) { await loadPersonPhoto() }
        }
    }

    private func loadPersonPhoto() async {
        guard let personSelection else { return }
        do {
            guard let data = try await personSelection.loadTransferable(type: Data.self) else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Pyxis-person-\(UUID().uuidString).jpg")
            try data.write(to: url, options: .atomic)
            personURL = url
            generatedURL = nil
            errorMessage = nil
        } catch {
            errorMessage = "Your photo could not be opened."
        }
    }

    private func generate() async {
        guard let personURL else { return }
        let garmentURLs = items.compactMap { item -> URL? in
            guard let storage = try? ImageStorageService() else { return nil }
            return storage.url(for: item.imageCutoutPath ?? item.imageOriginalPath)
        }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            let data = try await service.makeTryOn(personURL: personURL, garmentURLs: garmentURLs)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Pyxis-try-on-\(UUID().uuidString).png")
            try data.write(to: url, options: .atomic)
            generatedURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
