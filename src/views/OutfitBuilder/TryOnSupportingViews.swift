import SwiftUI

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
                    Image(systemName: "hand.raised").font(.largeTitle)
                    Text(TryOnPrivacy.title).font(PyxisTypography.title)
                    Text(disclosure).font(PyxisTypography.body)
                    Text("Only photos selected for a try-on are sent. Your closet and body measurements are not uploaded. Removing a reference photo does not delete previews you have chosen to save.")
                        .font(PyxisTypography.body).foregroundStyle(PyxisColors.secondaryText)
                    Text("Saved try-on photos are excluded from device backups. You can remove your reference photo or delete saved previews at any time.")
                        .font(PyxisTypography.body).foregroundStyle(PyxisColors.secondaryText)
                    Text(TryOnPrivacy.fitDisclaimer).font(PyxisTypography.label)
                    if requestsConsent {
                        Button("AGREE AND TRY ON", action: agree).buttonStyle(MinimalButtonStyle())
                        Button("NOT NOW") { dismiss() }.font(PyxisTypography.label)
                    } else if hasConsent {
                        Button("WITHDRAW PHOTO PROCESSING PERMISSION", role: .destructive) { revoke(); dismiss() }
                            .font(PyxisTypography.label)
                    }
                }.padding(PyxisSpacing.lg)
            }.navigationTitle("PRIVACY").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("CLOSE") { dismiss() } } }
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
                if items.isEmpty { Text("Add clothing to your closet, or use Add a photo to try something new.") }
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
            }.navigationTitle("YOUR CLOSET").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("CLOSE") { dismiss() } } }
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
                        ContentUnavailableView("No saved previews", systemImage: "photo.stack", description: Text("Save a try-on to keep it here, even when your allowance runs out."))
                    }
                    ForEach(model.previews) { preview in
                        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                            LocalImageView(url: model.previewURL(preview)).frame(maxWidth: .infinity).frame(height: 400)
                            Text(preview.garmentNames.joined(separator: " · ")).font(PyxisTypography.label)
                            Text(preview.createdAt.formatted(date: .abbreviated, time: .omitted)).font(PyxisTypography.label)
                                .foregroundStyle(PyxisColors.secondaryText)
                            HStack {
                                if let url = model.previewURL(preview) {
                                    ShareLink(item: url) { Label("SHARE", systemImage: "square.and.arrow.up") }
                                }
                                Spacer()
                                Button("DELETE", role: .destructive) { pendingDeletion = preview }
                            }.font(PyxisTypography.label)
                        }
                    }
                    if let error = model.errorMessage { InlineErrorMessage(message: error) }
                }.padding(PyxisSpacing.md)
            }.navigationTitle("SAVED PREVIEWS").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("CLOSE") { dismiss() } } }
                .confirmationDialog("Delete this preview from this device?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
                    Button("DELETE PREVIEW", role: .destructive) { if let preview = pendingDeletion { model.deletePreview(preview) }; pendingDeletion = nil }
                }
        }
    }
}
