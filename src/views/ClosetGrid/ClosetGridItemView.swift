import SwiftUI

struct ClosetGridItemView: View {
    let item: ClosetItem

    private var imageURL: URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            LocalImageView(url: imageURL, revision: imageRevision)
                .frame(height: 166)
                .padding(.horizontal, PyxisSpacing.sm)

            if let displayName = item.displayName, !displayName.isEmpty {
                Text(displayName.uppercased())
                    .font(PyxisTypography.editorialBody)
                    .foregroundStyle(PyxisColors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .tracking(0.8)
            }

            ItemCodeLabel(code: item.itemCode)
                .opacity(0.65)
        }
        .frame(minWidth: 150, minHeight: 213)
        .padding(.vertical, PyxisSpacing.sm)
        .catalogTileBackground()
        .contentShape(Rectangle())
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
    }

    private var imageRevision: Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
