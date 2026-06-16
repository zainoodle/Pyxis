import SwiftUI

struct UppercaseNavLabel: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title.uppercased())
            .font(PyxisTypography.nav)
            .foregroundStyle(isActive ? PyxisColors.text : PyxisColors.inactiveText)
            .lineLimit(1)
    }
}

struct ItemCodeLabel: View {
    let code: String

    var body: some View {
        Text(code.uppercased())
            .font(PyxisTypography.code)
            .foregroundStyle(PyxisColors.text)
            .lineLimit(1)
            .accessibilityLabel("Item code \(code)")
    }
}

struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PyxisTypography.body)
            .foregroundStyle(PyxisColors.text)
            .padding(.horizontal, PyxisSpacing.md)
            .padding(.vertical, PyxisSpacing.sm)
            .background(PyxisColors.field)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

struct EmptyPyxisState: View {
    let action: () -> Void

    var body: some View {
        Button("ADD FIRST ITEM", action: action)
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Add first item")
    }
}
