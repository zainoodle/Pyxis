import SwiftUI

struct UppercaseNavLabel: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title.uppercased())
            .font(PyxisTypography.editorialLabel)
            .tracking(1.5)
            .foregroundStyle(isActive ? PyxisColors.text : PyxisColors.secondaryText)
            .lineLimit(1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct ItemCodeLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let code: String

    var body: some View {
        Text(code.uppercased())
            .font(PyxisTypography.editorialLabel)
            .tracking(1)
            .foregroundStyle(PyxisColors.text)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Item code \(code)")
    }
}

struct MinimalButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PyxisTypography.button)
            .tracking(0.2)
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
                    .stroke(PyxisColors.controlBorder, lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
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
    func body(content: Content) -> some View {
        content
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
        Text(message)
            .font(PyxisTypography.label)
            .foregroundStyle(PyxisColors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(message)
    }
}
