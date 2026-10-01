import SwiftUI

struct PyxisRootView: View {
    @State private var selectedSection: AppSection = .closet
    @State private var builderFocusItemID: UUID?
    @State private var builderRequestID = UUID()
    @State private var isShowingBuilder = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedSection) {
                NavigationStack {
                    ClosetGridView { itemID in
                        builderFocusItemID = itemID
                        builderRequestID = UUID()
                        selectedSection = .fits
                        isShowingBuilder = true
                    }
                    .navigationBarHidden(true)
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem { tabLabel(.closet) }
                .tag(AppSection.closet)

                NavigationStack {
                    SavedFitsGalleryView(
                        buildAction: {
                            builderFocusItemID = nil
                            builderRequestID = UUID()
                            isShowingBuilder = true
                        }
                    )
                    .navigationBarHidden(true)
                    .navigationDestination(isPresented: $isShowingBuilder) {
                        OutfitBuilderView(initialItemID: builderFocusItemID)
                            .id(builderRequestID)
                            .navigationBarHidden(true)
                    }
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem { tabLabel(.fits) }
                .tag(AppSection.fits)

                NavigationStack {
                    ProfileView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem { tabLabel(.profile) }
                .tag(AppSection.profile)
            }
            .tint(PyxisColors.text)
            .toolbar(.hidden, for: .tabBar)
            EditorialTabBar(selection: $selectedSection)
        }
        .background(PyxisColors.background.ignoresSafeArea())
    }

    private func tabLabel(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
    }
}
