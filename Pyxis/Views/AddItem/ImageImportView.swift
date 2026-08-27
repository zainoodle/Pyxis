import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ImageImportView: View {
    let onSelect: (URL) -> Void
    @State private var isShowingImporter = false
    @State private var isShowingCamera = false
    @State private var isDropTargeted = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importMessage: String?

    var body: some View {
        VStack(spacing: PyxisSpacing.md) {
            Button("TAKE PHOTO") {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    importMessage = "Camera unavailable"
                    return
                }
                isShowingCamera = true
            }
            .buttonStyle(MinimalButtonStyle())
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            .accessibilityLabel("Take a photo of a clothing item")
            .accessibilityValue(
                UIImagePickerController.isSourceTypeAvailable(.camera)
                    ? "Available"
                    : "Unavailable on this device"
            )

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("PHOTO LIBRARY")
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Choose clothing image from photo library")

            Button("CHOOSE FILE") {
                isShowingImporter = true
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Choose clothing image file")

            #if DEBUG
            Button("DEMO IMAGE") {
                if let url = makeDemoImageURL() {
                    onSelect(url)
                }
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Import demo clothing image")
            #endif

            Text("DROP IMAGE")
                .font(PyxisTypography.label)
                .foregroundStyle(isDropTargeted ? PyxisColors.text : PyxisColors.inactiveText)

            if let importMessage {
                Text(importMessage.uppercased())
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PyxisColors.background)
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier], isTargeted: $isDropTargeted) { providers in
            loadFirstURL(from: providers)
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else {
                return
            }

            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    reportImportFailure()
                    return
                }

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Pyxis-photo-\(UUID().uuidString).jpg")
                try data.write(to: url, options: .atomic)
                finishImport(url)
            } catch {
                reportImportFailure()
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                finishImport(url)
            } else if case .failure = result {
                reportImportFailure()
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                isShowingCamera = false
                finishCameraCapture(image)
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func loadFirstURL(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        finishImport(url)
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        finishImport(url)
                    }
                } else {
                    DispatchQueue.main.async {
                        reportImportFailure()
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url else {
                    return
                }

                let temporaryURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Pyxis-drop-\(UUID().uuidString)")
                    .appendingPathExtension(url.pathExtension.isEmpty ? "png" : url.pathExtension)

                do {
                    try FileManager.default.copyItem(at: url, to: temporaryURL)
                    DispatchQueue.main.async {
                        finishImport(temporaryURL)
                    }
                } catch {
                    DispatchQueue.main.async {
                        reportImportFailure()
                    }
                }
            }
            return true
        }
        return false
    }

    private func finishImport(_ url: URL) {
        importMessage = nil
        onSelect(url)
    }

    private func reportImportFailure() {
        importMessage = "Import failed"
    }

    private func finishCameraCapture(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            reportImportFailure()
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-camera-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            finishImport(url)
        } catch {
            reportImportFailure()
        }
    }

    #if DEBUG
    private func makeDemoImageURL() -> URL? {
        let size = CGSize(width: 720, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            UIColor(white: 0.08, alpha: 1).setFill()
            let rect = CGRect(x: 180, y: 150, width: 360, height: 520)
            let shirt = UIBezierPath()
            shirt.move(to: CGPoint(x: rect.midX - 82, y: rect.minY + 34))
            shirt.addLine(to: CGPoint(x: rect.midX - 176, y: rect.minY + 126))
            shirt.addLine(to: CGPoint(x: rect.midX - 126, y: rect.minY + 210))
            shirt.addLine(to: CGPoint(x: rect.midX - 90, y: rect.minY + 176))
            shirt.addLine(to: CGPoint(x: rect.midX - 106, y: rect.maxY - 36))
            shirt.addLine(to: CGPoint(x: rect.midX + 106, y: rect.maxY - 36))
            shirt.addLine(to: CGPoint(x: rect.midX + 90, y: rect.minY + 176))
            shirt.addLine(to: CGPoint(x: rect.midX + 126, y: rect.minY + 210))
            shirt.addLine(to: CGPoint(x: rect.midX + 176, y: rect.minY + 126))
            shirt.addLine(to: CGPoint(x: rect.midX + 82, y: rect.minY + 34))
            shirt.addQuadCurve(to: CGPoint(x: rect.midX - 82, y: rect.minY + 34), controlPoint: CGPoint(x: rect.midX, y: rect.minY + 112))
            shirt.close()
            shirt.fill()
        }

        guard let data = image.pngData() else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-black-shirt-demo-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            reportImportFailure()
            return nil
        }
    }
    #endif
}
