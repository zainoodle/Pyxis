import SwiftUI
import UIKit

struct EditorialTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let axis: Axis
    let keyboardType: UIKeyboardType
    let alignment: TextAlignment
    @FocusState private var isFocused: Bool

    init(_ title: String, placeholder: String = "", text: Binding<String>, axis: Axis = .horizontal,
         keyboardType: UIKeyboardType = .default, alignment: TextAlignment = .leading) {
        self.title = title
        self.placeholder = placeholder
        _text = text
        self.axis = axis
        self.keyboardType = keyboardType
        self.alignment = alignment
    }

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .font(PyxisTypography.control)
            .keyboardType(keyboardType)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { isFocused = true })
            .accessibilityLabel(title)
    }
}
