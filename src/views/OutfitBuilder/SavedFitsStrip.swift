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
                            Button {
                                openOutfit(outfit)
                            } label: {
                                SavedFitCard(
                                    outfit: outfit,
                                    items: items,
                                    isRecent: outfit.id == recentOutfitID
                                )
                            }
                            .buttonStyle(.plain)
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
    var isGallery = false

    private var selectedItems: [ClosetItem] {
        outfit.itemIDs.compactMap { itemID in
            items.first { $0.id == itemID }
        }
    }

    var body: some View {
        Group {
            if isGallery {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PyxisSpacing.md) {
                        itemImages
                        fitDetails
                        Spacer(minLength: 0)
                        disclosureIcon
                    }

                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        itemImages
                        HStack {
                            fitDetails
                            Spacer(minLength: 0)
                            disclosureIcon
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PyxisSpacing.md)
            } else {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    itemImages
                    fitDetails
                }
                .frame(width: 150, alignment: .leading)
                .padding(PyxisSpacing.sm)
            }
        }
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
        .accessibilityLabel("Open saved fit \(outfit.name ?? outfit.dateCreated.formatted(date: .abbreviated, time: .omitted)), \(selectedItems.count) pieces")
    }

    private var itemImages: some View {
        HStack(spacing: PyxisSpacing.xs) {
            ForEach(selectedItems.prefix(3)) { item in
                SavedFitItemImage(item: item)
            }
        }
        .frame(height: 70)
    }

    private var fitDetails: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text(outfit.name?.uppercased() ?? outfit.dateCreated.formatted(date: .numeric, time: .omitted))
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.text)
                .lineLimit(isGallery ? 2 : 1)

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
    }

    private var disclosureIcon: some View {
        Image(systemName: "chevron.right")
            .font(PyxisTypography.label)
            .foregroundStyle(PyxisColors.inactiveText)
            .accessibilityHidden(true)
    }
}

struct SavedFitItemImage: View {
    let item: ClosetItem

    private var imageURL: URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    var body: some View {
        LocalImageView(
            url: imageURL,
            revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
        )
            .frame(width: 42, height: 66)
    }
}
