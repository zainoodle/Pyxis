import SwiftData
import SwiftUI

struct SavedFitsGalleryView: View {
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    let buildAction: (() -> Void)?

    init(buildAction: (() -> Void)? = nil) {
        self.buildAction = buildAction
    }

    var body: some View {
        VStack(spacing: PyxisSpacing.lg) {
            PrimaryPageHeader()

            if outfits.isEmpty {
                VStack(spacing: PyxisSpacing.md) {
                    Text("NO SAVED FITS")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.inactiveText)
                    if let buildAction {
                        Button("BUILD A FIT", action: buildAction)
                            .buttonStyle(MinimalButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, PyxisSpacing.xl)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PyxisSpacing.md) {
                        Text("SAVED OUTFITS")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.secondaryText)
                            .accessibilityAddTraits(.isHeader)

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
        .padding(.horizontal, PyxisSpacing.md)
        .padding(.bottom, PyxisSpacing.md)
        .background(PyxisColors.background)
    }
}
