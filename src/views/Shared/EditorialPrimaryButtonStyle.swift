import SwiftUI

struct EditorialPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PyxisTypography.button)
            .foregroundStyle(PyxisColors.background)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.vertical, 2)
            .background(PyxisColors.text, in: RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
    }
}
