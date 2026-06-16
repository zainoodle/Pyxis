import SwiftUI

struct ClosetGridItemView: View {
    let item: ClosetItem

    private var imageURL: URL? {
        guard let storage = try? ImageStorageService() else {
            return nil
        }
        if let thumbnailPath = item.thumbnailPath {
            return storage.url(for: thumbnailPath)
        }
        if let cutoutPath = item.imageCutoutPath {
            return storage.url(for: cutoutPath)
        }
        return storage.url(for: item.imageOriginalPath)
    }

    var body: some View {
        VStack(spacing: ArchiveSpacing.sm) {
            LocalImageView(url: imageURL)
                .frame(height: 178)
                .padding(.horizontal, ArchiveSpacing.sm)

            ItemCodeLabel(code: item.itemCode)

            if let displayName = item.displayName, !displayName.isEmpty {
                Text(displayName.uppercased())
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 150, minHeight: 230)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
