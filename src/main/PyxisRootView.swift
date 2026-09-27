import SwiftUI

struct PyxisRootView: View {
    @State private var selectedSection: AppSection = .closet
    @State private var builderFocusItemID: UUID?
    @State private var isShowingBuilder = false

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab(AppSection.closet.title, systemImage: AppSection.closet.systemImage, value: .closet) {
                NavigationStack {
                    ClosetGridView { itemID in
                        builderFocusItemID = itemID
                        selectedSection = .fits
                        isShowingBuilder = true
                    }
                    .navigationBarHidden(true)
                }
            }

            Tab(AppSection.fits.title, systemImage: AppSection.fits.systemImage, value: .fits) {
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
            }

            Tab(AppSection.profile.title, systemImage: AppSection.profile.systemImage, value: .profile) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tint(PyxisColors.text)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorialTabBar(selection: $selectedSection)
        }
    }
}
