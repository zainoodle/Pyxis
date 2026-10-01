import SwiftUI

struct SavedTryOnEntryView: View {
    @StateObject private var model = TryOnViewModel()
    var body: some View { TryOnSavedPreviewsView(model: model) }
}

struct TryOnPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var disclosure: String = TryOnPrivacy.disclosure
    let hasConsent: Bool
    let requestsConsent: Bool
    let agree: () -> Void
    let revoke: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                    Text(disclosure).font(PyxisTypography.prose)
                    Text("Only selected photos are sent. Your closet and measurements stay on this device.")
                        .font(PyxisTypography.prose).foregroundStyle(PyxisColors.secondaryText)
                    Text("Saved photos and previews are excluded from backups. You can delete them anytime. Removing your reference photo keeps saved previews.")
                        .font(PyxisTypography.prose).foregroundStyle(PyxisColors.secondaryText)
                    Text(TryOnPrivacy.fitDisclaimer).font(PyxisTypography.proseCaption)
                    if requestsConsent {
                        Button("Agree and generate", action: agree).buttonStyle(EditorialPrimaryButtonStyle())
                        Button { dismiss() } label: { Text("Not now").font(PyxisTypography.control).frame(minHeight: 44) }
                    } else if hasConsent {
                        Button(role: .destructive) { revoke(); dismiss() } label: {
                            Text("Withdraw permission").font(PyxisTypography.control).frame(minHeight: 44)
                        }
                    }
                }.padding(PyxisSpacing.lg)
            }.editorialNavigationTitle("Photo processing")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

struct TryOnClosetPicker: View {
    @Environment(\.dismiss) private var dismiss
    let items: [ClosetItem]
    let selectedIDs: Set<UUID>
    let select: (ClosetItem) -> Void
    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty { Text("No pieces yet. Use Add photo to choose one.").font(PyxisTypography.prose) }
                ForEach(items) { item in
                    Button { select(item) } label: {
                        HStack {
                            LocalImageView(url: ImageStorageService.shared?.url(for: item.imageCutoutPath ?? item.imageOriginalPath))
                                .frame(width: 52, height: 64)
                            Text(item.displayName ?? item.subtype.rawValue).font(PyxisTypography.body)
                            Spacer()
                            if selectedIDs.contains(item.id) { Image(systemName: "checkmark") }
                        }
                    }.disabled(selectedIDs.contains(item.id))
                }
            }.editorialNavigationTitle("Your closet")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

struct TryOnSavedPreviewsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: TryOnViewModel
    @State private var pendingDeletion: SavedTryOn?
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: PyxisSpacing.lg) {
                    if model.previews.isEmpty {
                        ContentUnavailableView("No saved previews", systemImage: "photo.stack", description: Text("Saved previews will appear here."))
                    }
                    ForEach(model.previews) { preview in
                        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                            LocalImageView(url: model.previewURL(preview)).frame(maxWidth: .infinity).frame(height: 400)
                            Text(preview.garmentNames.joined(separator: " · ")).font(PyxisTypography.label)
                            Text(preview.createdAt.formatted(date: .abbreviated, time: .omitted)).font(PyxisTypography.label)
                                .foregroundStyle(PyxisColors.secondaryText)
                            HStack {
                                if let url = model.previewURL(preview) {
                                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                                }
                                Spacer()
                                Button("Delete", role: .destructive) { pendingDeletion = preview }
                            }.font(PyxisTypography.label)
                        }
                    }
                    if let error = model.errorMessage { InlineErrorMessage(message: error) }
                }.padding(PyxisSpacing.md)
            }.editorialNavigationTitle("Saved previews")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
                .confirmationDialog("Delete this preview from this device?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
                    Button("Delete preview", role: .destructive) { if let preview = pendingDeletion { model.deletePreview(preview) }; pendingDeletion = nil }
                }
        }
    }
}
