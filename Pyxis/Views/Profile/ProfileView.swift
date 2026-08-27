import SwiftUI

struct ProfileView: View {
    @State private var selectedClosetID: UUID?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ClosetManagementView(selectedClosetID: $selectedClosetID)
                } label: {
                    settingsRow("MANAGE CLOSETS", detail: "Organize your local archive", systemImage: "folder")
                }

                NavigationLink {
                    SizingProfileView(showsCloseButton: false)
                } label: {
                    settingsRow("FIT PASSPORT", detail: "Measurements stay on this device", systemImage: "ruler")
                }
            } header: {
                Text("ORGANIZE")
            }

            Section {
                HStack(alignment: .top, spacing: PyxisSpacing.md) {
                    Image(systemName: AIGarmentStudioService.isConfigured ? "sparkles" : "sparkles.slash")
                        .frame(width: 24)
                        .foregroundStyle(PyxisColors.secondaryText)

                    VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                        Text("AI STUDIO")
                            .font(PyxisTypography.body)
                        Text(
                            AIGarmentStudioService.isConfigured
                                ? "OPTIONAL REMOTE GENERATION IS CONFIGURED"
                                : "UNAVAILABLE IN THIS BUILD"
                        )
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                    }
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("CAPABILITIES")
            } footer: {
                Text("Your closet, search, fits, and Fit Passport work offline. AI Studio uploads only photos you explicitly choose when it is configured.")
                    .font(PyxisTypography.body)
            }

            Section {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    Text("PRIVATE BY DEFAULT")
                        .font(PyxisTypography.body)
                    Text("No accounts, ads, tracking, or cloud sync. Closet images are stored in protected local app storage.")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
            } header: {
                Text("ABOUT PYXIS")
            }
        }
        .scrollContentBackground(.hidden)
        .background(PyxisColors.background)
        .navigationTitle("PROFILE")
    }

    private func settingsRow(_ title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: PyxisSpacing.md) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(PyxisColors.secondaryText)
            VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                Text(title)
                    .font(PyxisTypography.body)
                Text(detail.uppercased())
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
    }
}
