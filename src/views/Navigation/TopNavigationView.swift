import SwiftUI

struct TopNavigationView: View {
    let addAction: () -> Void

    var body: some View {
        PrimaryPageHeader(title: "CLOSET") {
            Button(action: addAction) {
                UppercaseNavLabel(title: "New", isActive: false)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Add new item")
        }
    }
}
