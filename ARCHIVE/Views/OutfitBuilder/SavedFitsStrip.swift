import SwiftUI

struct SavedFitsStrip: View {
    let outfits: [Outfit]
    let items: [ClosetItem]
    let recentOutfitID: UUID?
    let openOutfit: (Outfit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ArchiveSpacing.sm) {
            HStack {
                Text("SAVED FITS")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)

                Spacer()

                Text("\(outfits.count)")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.inactiveText)
            }

            if outfits.isEmpty {
                Text("NO SAVED FITS")
                    .font(ArchiveTypography.body)
                    .foregroundStyle(ArchiveColors.inactiveText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, ArchiveSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ArchiveSpacing.md) {
                        ForEach(outfits.prefix(12)) { outfit in
                            SavedFitCard(
                                outfit: outfit,
                                items: items,
                                isRecent: outfit.id == recentOutfitID
                            ) {
                                openOutfit(outfit)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.easeOut(duration: 0.24), value: outfits.map(\.id))
                }
            }
        }
    }
}

struct SavedFitCard: View {
    let outfit: Outfit
    let items: [ClosetItem]
    let isRecent: Bool
    let action: () -> Void

    private var selectedItems: [ClosetItem] {
        outfit.itemIDs.compactMap { itemID in
            items.first { $0.id == itemID }
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ArchiveSpacing.sm) {
                HStack(spacing: ArchiveSpacing.xs) {
                    ForEach(selectedItems.prefix(3)) { item in
                        SavedFitItemImage(item: item)
                    }
                }
                .frame(height: 70)

                Text(outfit.name?.uppercased() ?? outfit.dateCreated.formatted(date: .numeric, time: .omitted))
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.text)
                    .lineLimit(1)

                Text("\(selectedItems.count) PIECES")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)

                if isRecent {
                    Text("SAVED")
                        .font(ArchiveTypography.label)
                        .foregroundStyle(ArchiveColors.secondaryText)
                        .transition(.opacity)
                }
            }
            .frame(width: 150, alignment: .leading)
            .padding(ArchiveSpacing.sm)
            .background(ArchiveColors.field)
            .overlay(alignment: .topTrailing) {
                if isRecent {
                    Circle()
                        .fill(ArchiveColors.text)
                        .frame(width: 6, height: 6)
                        .padding(ArchiveSpacing.sm)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isRecent ? 1.02 : 1)
            .animation(.easeOut(duration: 0.18), value: isRecent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open saved fit")
    }
}

struct SavedFitItemImage: View {
    let item: ClosetItem

    private var imageURL: URL? {
        guard let storage = try? ImageStorageService() else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    var body: some View {
        LocalImageView(url: imageURL)
            .frame(width: 42, height: 66)
    }
}
