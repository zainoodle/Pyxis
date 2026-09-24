import SwiftUI

struct ProfileView: View {
    @State private var selectedClosetID: UUID?

    var body: some View {
        List {
            NavigationLink {
                ClosetManagementView(selectedClosetID: $selectedClosetID)
            } label: {
                settingsRow("MANAGE CLOSETS", systemImage: "folder")
            }

            NavigationLink {
                SizingProfileView(showsCloseButton: false)
            } label: {
                settingsRow("FIT PASSPORT", systemImage: "ruler")
            }
        }
        .scrollContentBackground(.hidden)
        .background(PyxisColors.background)
        .navigationTitle("PROFILE")
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: PyxisSpacing.md) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(PyxisColors.secondaryText)
            Text(title)
                .font(PyxisTypography.body)
        }
    }
}
