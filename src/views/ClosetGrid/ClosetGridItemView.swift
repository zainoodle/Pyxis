import SwiftUI

struct ClosetGridItemView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: ClosetItem

    private var imageURL: URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredFullSizePath(for: item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            GarmentStage(url: imageURL, revision: imageRevision)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 190 : 150)

            Text(item.displayName ?? item.subtype.rawValue.capitalized)
                .font(PyxisTypography.editorialBody)
                .foregroundStyle(PyxisColors.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            ItemCodeLabel(code: item.itemCode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, PyxisSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
    }

    private var imageRevision: Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
