import SwiftUI

struct OutfitCarouselItemView: View {
    let item: ClosetItem
    let isSelected: Bool
    let action: () -> Void

    private var imageURL: URL? {
        guard let storage = try? ImageStorageService() else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: ArchiveSpacing.sm) {
                LocalImageView(url: imageURL)
                    .frame(height: 126)
                    .padding(.horizontal, ArchiveSpacing.sm)

                ItemCodeLabel(code: item.itemCode)

                Text(ClosetItemImageResolver.hasCutout(for: item) ? "READY" : "ORIGINAL ONLY")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(isSelected ? ArchiveColors.secondaryText : ArchiveColors.inactiveText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
    }
}
