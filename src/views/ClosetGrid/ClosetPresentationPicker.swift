import SwiftUI

enum ClosetPresentation: String, CaseIterable {
    case gallery, grid
    var title: String { rawValue.capitalized }
}

struct ClosetPresentationPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 18) {
            ForEach(ClosetPresentation.allCases, id: \.rawValue) { mode in
                Button { selection = mode.rawValue } label: {
                    Text(mode.title)
                        .font(PyxisTypography.control)
                        .foregroundStyle(selection == mode.rawValue ? PyxisColors.text : PyxisColors.inactiveText)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if selection == mode.rawValue {
                                Rectangle().fill(PyxisColors.text).frame(height: 1)
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
