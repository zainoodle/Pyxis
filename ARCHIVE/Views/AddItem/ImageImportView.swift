import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImageImportView: View {
    let onSelect: (URL) -> Void
    @State private var isShowingImporter = false
    @State private var isDropTargeted = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: ArchiveSpacing.md) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("PHOTO LIBRARY")
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Choose clothing image from photo library")

            Button("IMPORT IMAGE") {
                isShowingImporter = true
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Import clothing image")

            Text("DROP IMAGE")
                .font(ArchiveTypography.label)
                .foregroundStyle(isDropTargeted ? ArchiveColors.text : ArchiveColors.inactiveText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ArchiveColors.background)
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier], isTargeted: $isDropTargeted) { providers in
            loadFirstURL(from: providers)
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto,
                  let data = try? await selectedPhoto.loadTransferable(type: Data.self) else {
                return
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ARCHIVE-photo-\(UUID().uuidString).jpg")
            try? data.write(to: url, options: .atomic)
            onSelect(url)
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                onSelect(url)
            }
        }
    }

    private func loadFirstURL(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    onSelect(url)
                }
            } else if let url = item as? URL {
                DispatchQueue.main.async {
                    onSelect(url)
                }
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url else {
                    return
                }

                let temporaryURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ARCHIVE-drop-\(UUID().uuidString)")
                    .appendingPathExtension(url.pathExtension.isEmpty ? "png" : url.pathExtension)

                try? FileManager.default.copyItem(at: url, to: temporaryURL)
                DispatchQueue.main.async {
                    onSelect(temporaryURL)
                }
            }
        }
        return true
    }
}
