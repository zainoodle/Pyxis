import SwiftUI

struct SavedFitsStrip: View {
    let outfits: [Outfit]
    let items: [ClosetItem]
    let recentOutfitID: UUID?
    let openOutfit: (Outfit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            HStack {
                Text("SAVED FITS")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)

                Spacer()

                Text("\(outfits.count)")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.inactiveText)
            }

            if outfits.isEmpty {
                Text("NO SAVED FITS")
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.inactiveText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PyxisSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PyxisSpacing.md) {
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
            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                HStack(spacing: PyxisSpacing.xs) {
                    ForEach(selectedItems.prefix(3)) { item in
                        SavedFitItemImage(item: item)
                    }
                }
                .frame(height: 70)

                Text(outfit.name?.uppercased() ?? outfit.dateCreated.formatted(date: .numeric, time: .omitted))
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.text)
                    .lineLimit(1)

                Text("\(selectedItems.count) PIECES")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)

                if isRecent {
                    Text("SAVED")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .transition(.opacity)
                }
            }
            .frame(width: 150, alignment: .leading)
            .padding(PyxisSpacing.sm)
            .background(PyxisColors.field)
            .overlay(alignment: .topTrailing) {
                if isRecent {
                    Circle()
                        .fill(PyxisColors.text)
                        .frame(width: 6, height: 6)
                        .padding(PyxisSpacing.sm)
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
