import SwiftUI

/// Native back navigation, with the same quiet mono title on detail and sheet screens.
private struct EditorialNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.text)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

extension View {
    func editorialNavigationTitle(_ title: String) -> some View {
        modifier(EditorialNavigationTitle(title: title))
    }
}
