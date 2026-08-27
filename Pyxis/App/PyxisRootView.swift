import SwiftUI

struct PyxisRootView: View {
    @State private var selectedSection: AppSection = .closet
    @State private var builderFocusItemID: UUID?

    var body: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                ClosetGridView { itemID in
                    builderFocusItemID = itemID
                    selectedSection = .build
                }
                .navigationBarHidden(true)
            }
            .tabItem { tabLabel(.closet) }
            .tag(AppSection.closet)

            NavigationStack {
                OutfitBuilderView(initialItemID: builderFocusItemID, showsCloseButton: false)
                    .navigationBarHidden(true)
            }
            .tabItem { tabLabel(.build) }
            .tag(AppSection.build)

            NavigationStack {
                SavedFitsGalleryView(
                    buildAction: { selectedSection = .build },
                    showsCloseButton: false
                )
                .navigationBarHidden(true)
            }
            .tabItem { tabLabel(.fits) }
            .tag(AppSection.fits)

            NavigationStack {
                ProfileView()
            }
            .tabItem { tabLabel(.profile) }
            .tag(AppSection.profile)
        }
        .tint(PyxisColors.text)
    }

    private func tabLabel(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
    }
}
