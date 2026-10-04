import SwiftUI

enum ClosetPresentation: String, CaseIterable {
    case gallery, grid
    var title: String { rawValue.capitalized }
}

struct ClosetPresentationPicker: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: String

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 24))
        return layout {
            ForEach(ClosetPresentation.allCases, id: \.rawValue) { mode in
                Button { selection = mode.rawValue } label: {
                    Text(mode.title.uppercased())
                        .font(PyxisTypography.closetBrowse)
                        .fontWeight(selection == mode.rawValue ? .semibold : .regular)
                        .tracking(1.4)
                        .fixedSize(horizontal: true, vertical: true)
                        .foregroundStyle(selection == mode.rawValue ? PyxisColors.text : PyxisColors.inactiveText)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            if selection == mode.rawValue {
                                Rectangle().fill(PyxisColors.text).frame(height: 2)
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.title) view")
                .accessibilityAddTraits(selection == mode.rawValue ? .isSelected : [])
                .accessibilityIdentifier("closet.\(mode.rawValue)")
            }
        }
    }
}
