import SwiftUI

struct EditorialMenuPicker<Selection: Hashable, Options: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: String
    @Binding var selection: Selection
    @ViewBuilder let options: () -> Options

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        layout {
            Text(title).font(PyxisTypography.control)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Menu {
                Picker(title, selection: $selection, content: options)
            } label: {
                HStack(spacing: 8) {
                    Text(value).fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
                }
                .font(PyxisTypography.control)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
