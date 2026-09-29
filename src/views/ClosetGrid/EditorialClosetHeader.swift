import SwiftUI

struct EditorialClosetHeader: View {
    let addAction: () -> Void
    let searchAction: () -> Void

    var body: some View {
        PrimaryPageHeader(title: "Closet") {
            HStack(spacing: 0) {
                HeaderIconButton(symbol: "magnifyingglass", label: "Search closet", identifier: "closet.openSearch", action: searchAction)
                HeaderIconButton(symbol: "plus", label: "Add new item", identifier: "closet.add", action: addAction)
            }
        }
        .padding(.horizontal, 24)
    }
}
