import SwiftUI

struct UppercaseNavLabel: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title.uppercased())
            .font(ArchiveTypography.nav)
            .foregroundStyle(isActive ? ArchiveColors.text : ArchiveColors.inactiveText)
            .lineLimit(1)
    }
}

struct ItemCodeLabel: View {
    let code: String

    var body: some View {
        Text(code.uppercased())
            .font(ArchiveTypography.code)
            .foregroundStyle(ArchiveColors.text)
            .lineLimit(1)
            .accessibilityLabel("Item code \(code)")
    }
}

struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArchiveTypography.body)
            .foregroundStyle(ArchiveColors.text)
            .padding(.horizontal, ArchiveSpacing.md)
            .padding(.vertical, ArchiveSpacing.sm)
            .background(ArchiveColors.field)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

struct EmptyArchiveState: View {
    let action: () -> Void

    var body: some View {
        Button("ADD FIRST ITEM", action: action)
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Add first item")
    }
}
