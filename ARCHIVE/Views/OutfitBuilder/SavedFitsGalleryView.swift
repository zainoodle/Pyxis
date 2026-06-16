import SwiftData
import SwiftUI

struct SavedFitsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @State private var selectedOutfit: Outfit?

    var body: some View {
        VStack(spacing: ArchiveSpacing.lg) {
            HStack {
                Text("FITS")
                    .font(ArchiveTypography.title)
                Spacer()
                Button("CLOSE") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            if outfits.isEmpty {
                Spacer()
                Text("NO SAVED FITS")
                    .font(ArchiveTypography.body)
                    .foregroundStyle(ArchiveColors.inactiveText)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: ArchiveSpacing.lg)],
                        spacing: ArchiveSpacing.lg
                    ) {
                        ForEach(outfits) { outfit in
                            SavedFitCard(outfit: outfit, items: items, isRecent: false) {
                                selectedOutfit = outfit
                            }
                        }
                    }
                    .padding(.top, ArchiveSpacing.md)
                }
            }
        }
        .padding(ArchiveSpacing.md)
        .background(ArchiveColors.background)
        .sheet(item: $selectedOutfit) { outfit in
            OutfitDetailView(outfit: outfit)
        }
    }
}
