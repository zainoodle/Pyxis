import SwiftUI

struct ClosetGridItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: ClosetItem

    private var imageURL: URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    var body: some View {
        VStack(spacing: PyxisSpacing.sm) {
            LocalImageView(url: imageURL, revision: imageRevision)
                .frame(height: colorScheme == .dark ? 166 : 178)
                .padding(.horizontal, PyxisSpacing.sm)
                .brightness(colorScheme == .dark ? 0.10 : 0)
                .background(colorScheme == .dark ? PyxisColors.background : PyxisColors.imageCanvas)

            ItemCodeLabel(code: item.itemCode)

            if let displayName = item.displayName, !displayName.isEmpty {
                Text(displayName.uppercased())
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minWidth: 150, minHeight: colorScheme == .dark ? 213 : 230)
        .padding(.vertical, colorScheme == .dark ? PyxisSpacing.sm : PyxisSpacing.md)
        .padding(.horizontal, PyxisSpacing.sm)
        .catalogTileBackground()
        .contentShape(Rectangle())
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
    }

    private var imageRevision: Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
