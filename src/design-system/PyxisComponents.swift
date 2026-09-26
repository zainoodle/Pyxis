import SwiftUI

struct UppercaseNavLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title.uppercased())
            .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.nav)
            .tracking(colorScheme == .dark ? 1.5 : 0)
            .foregroundStyle(isActive ? PyxisColors.text : PyxisColors.secondaryText)
            .lineLimit(1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct ItemCodeLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let code: String

    var body: some View {
        Text(code.uppercased())
            .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.code)
            .tracking(colorScheme == .dark ? 1 : 0)
            .foregroundStyle(PyxisColors.text)
            .lineLimit(1)
            .accessibilityLabel("Item code \(code)")
    }
}

struct MinimalButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.body)
            .tracking(colorScheme == .dark ? 1.2 : 0)
            .foregroundStyle(PyxisColors.text)
            .padding(.horizontal, PyxisSpacing.md)
            .padding(.vertical, PyxisSpacing.sm)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PyxisColors.field)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PyxisColors.hairline, lineWidth: 1)
            }
            .editorialGlow(cornerRadius: 8, strength: configuration.isPressed ? 0.4 : 0.7)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .contentShape(Rectangle())
    }
}

struct PremiumCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PyxisColors.surface)
                    .shadow(color: PyxisColors.shadow, radius: 18, x: 0, y: 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PyxisColors.hairline, lineWidth: 1)
            }
    }
}

private struct CatalogTileBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color.clear : PyxisColors.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PyxisColors.hairline)
                    .frame(height: 1)
            }
    }
}

extension View {
    func premiumCardBackground() -> some View {
        modifier(PremiumCardBackground())
    }

    func catalogTileBackground() -> some View {
        modifier(CatalogTileBackground())
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

struct InlineErrorMessage: View {
    let message: String

    var body: some View {
        Text(message.uppercased())
            .font(PyxisTypography.label)
            .foregroundStyle(PyxisColors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(message)
    }
}
