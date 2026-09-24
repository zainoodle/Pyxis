import SwiftData
import SwiftUI

struct SavedFitsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    let buildAction: (() -> Void)?
    let showsCloseButton: Bool

    init(buildAction: (() -> Void)? = nil, showsCloseButton: Bool = true) {
        self.buildAction = buildAction
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        VStack(spacing: PyxisSpacing.lg) {
            HStack {
                Text("FITS")
                    .font(PyxisTypography.title)
                Spacer()
                if showsCloseButton {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close saved fits")
                }
            }

            if outfits.isEmpty {
                Spacer()
                Text("NO SAVED FITS")
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.inactiveText)
                if let buildAction {
                    Button("BUILD A FIT") {
                        dismiss()
                        buildAction()
                    }
                    .buttonStyle(MinimalButtonStyle())
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: PyxisSpacing.md) {
                        ForEach(outfits) { outfit in
                            NavigationLink {
                                OutfitDetailView(outfit: outfit)
                            } label: {
                                SavedFitCard(outfit: outfit, items: items, isRecent: false, isGallery: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, PyxisSpacing.md)
                }
            }
        }
        .padding(PyxisSpacing.md)
        .background(PyxisColors.background)
    }
}
