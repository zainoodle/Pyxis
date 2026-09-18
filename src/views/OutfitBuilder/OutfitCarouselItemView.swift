import SwiftUI

struct OutfitCarouselItemView: View {
    let item: ClosetItem
    let isSelected: Bool
    let action: () -> Void

    private var imageURL: URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: PyxisSpacing.sm) {
                LocalImageView(url: imageURL, revision: imageRevision)
                    .frame(height: 126)
                    .padding(.horizontal, PyxisSpacing.sm)

                ItemCodeLabel(code: item.itemCode)

                Text(ClosetItemImageResolver.hasCutout(for: item) ? "READY" : "ORIGINAL ONLY")
                    .font(PyxisTypography.label)
                    .foregroundStyle(isSelected ? PyxisColors.secondaryText : PyxisColors.inactiveText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var imageRevision: Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
