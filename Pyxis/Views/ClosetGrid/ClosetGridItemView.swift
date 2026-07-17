import SwiftUI

struct ClosetGridItemView: View {
    let item: ClosetItem
    let action: () -> Void

    init(item: ClosetItem, action: @escaping () -> Void = {}) {
        self.item = item
        self.action = action
    }

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
                    .frame(height: 178)
                    .padding(.horizontal, PyxisSpacing.sm)

                ItemCodeLabel(code: item.itemCode)

                if let displayName = item.displayName, !displayName.isEmpty {
                    Text(displayName.uppercased())
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 150, minHeight: 230)
            .padding(.vertical, PyxisSpacing.md)
            .padding(.horizontal, PyxisSpacing.sm)
            .catalogTileBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.itemCode) \(item.displayName ?? item.subtype.rawValue)")
    }

    private var imageRevision: Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
