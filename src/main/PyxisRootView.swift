import SwiftUI

struct PyxisRootView: View {
    @State private var selectedSection: AppSection = .closet
    @State private var builderFocusItemID: UUID?
    @State private var isShowingBuilder = false

    var body: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                ClosetGridView { itemID in
                    builderFocusItemID = itemID
                    selectedSection = .fits
                    isShowingBuilder = true
                }
                .navigationBarHidden(true)
            }
            .tabItem { tabLabel(.closet) }
            .tag(AppSection.closet)

            NavigationStack {
                SavedFitsGalleryView(
                    buildAction: {
                        builderFocusItemID = nil
                        isShowingBuilder = true
                    }
                )
                .navigationBarHidden(true)
                .navigationDestination(isPresented: $isShowingBuilder) {
                    OutfitBuilderView(initialItemID: builderFocusItemID)
                        .navigationBarHidden(true)
                }
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
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorialTabBar(selection: $selectedSection)
        }
    }

    private func tabLabel(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
    }
}
