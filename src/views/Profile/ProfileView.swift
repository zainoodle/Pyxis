import SwiftUI

struct ProfileView: View {
    @AppStorage("pyxis.appearance") private var appearance = PyxisAppearance.system.rawValue
    @State private var selectedClosetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
            PrimaryPageHeader()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ORGANIZE")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, PyxisSpacing.sm)

                    NavigationLink {
                        ClosetManagementView(selectedClosetID: $selectedClosetID)
                    } label: {
                        settingsRow("MANAGE CLOSETS", systemImage: "folder")
                    }

                    Rectangle()
                        .fill(PyxisColors.hairline.opacity(0.35))
                        .frame(height: 1)

                    NavigationLink {
                        SizingProfileView()
                    } label: {
                        settingsRow("FIT PASSPORT", systemImage: "ruler")
                    }

                    Text("APPEARANCE")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .padding(.top, PyxisSpacing.lg)
                        .padding(.bottom, PyxisSpacing.sm)

                    Picker("APPEARANCE", selection: $appearance) {
                        ForEach(PyxisAppearance.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("App appearance")
                }
                .padding(.top, PyxisSpacing.md)
            }
        }
        .padding(.horizontal, PyxisSpacing.md)
        .padding(.bottom, PyxisSpacing.md)
        .background(PyxisColors.background)
        .navigationBarHidden(true)
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: PyxisSpacing.md) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(PyxisColors.secondaryText)
            Text(title)
                .font(PyxisTypography.body)

            Spacer(minLength: PyxisSpacing.sm)

            Image(systemName: "chevron.right")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.inactiveText)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
