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
        VStack(alignment: colorScheme == .dark ? .leading : .center, spacing: PyxisSpacing.sm) {
            LocalImageView(url: imageURL, revision: imageRevision)
                .frame(height: colorScheme == .dark ? 166 : 178)
                .padding(.horizontal, PyxisSpacing.sm)
                .background(colorScheme == .dark ? Color.clear : PyxisColors.imageCanvas)

            if let displayName = item.displayName, !displayName.isEmpty {
                Text(displayName.uppercased())
                    .font(colorScheme == .dark ? PyxisTypography.editorialBody : PyxisTypography.label)
                    .foregroundStyle(colorScheme == .dark ? PyxisColors.text : PyxisColors.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(colorScheme == .dark ? .leading : .center)
                    .tracking(colorScheme == .dark ? 0.8 : 0)
            }

            ItemCodeLabel(code: item.itemCode)
                .opacity(colorScheme == .dark ? 0.65 : 1)
        }
        .frame(minWidth: 150, minHeight: colorScheme == .dark ? 213 : 230)
        .padding(.vertical, colorScheme == .dark ? PyxisSpacing.sm : PyxisSpacing.md)
        .padding(.horizontal, colorScheme == .dark ? 0 : PyxisSpacing.sm)
        .catalogTileBackground()
        .contentShape(Rectangle())
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
    }

    private var imageRevision: Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
