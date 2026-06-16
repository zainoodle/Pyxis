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
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PyxisColors.field)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PyxisColors.hairline, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.55 : 1)
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

extension View {
    func premiumCardBackground() -> some View {
        modifier(PremiumCardBackground())
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
