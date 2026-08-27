import SwiftData
import SwiftUI

@main
struct PyxisApp: App {
    var body: some Scene {
        WindowGroup {
            StartupHostView()
                .preferredColorScheme(.light)
        }
    }
}

@MainActor
private struct StartupHostView: View {
    @State private var modelContainer: ModelContainer?
    @State private var didFail = false
    @State private var retryID = UUID()

    var body: some View {
        Group {
            if let modelContainer {
                PyxisRootView()
                    .modelContainer(modelContainer)
            } else if didFail {
                StartupFailureView {
                    didFail = false
                    retryID = UUID()
                }
            } else {
                ProgressView("OPENING LOCAL CLOSET")
                    .font(PyxisTypography.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PyxisColors.background)
            }
        }
        .task(id: retryID) {
            guard modelContainer == nil else { return }
            do {
                modelContainer = try SwiftDataContainer.makeAppContainer()
                didFail = false
            } catch {
                didFail = true
            }
        }
    }
}

private struct StartupFailureView: View {
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: PyxisSpacing.md) {
            Text("PYXIS COULD NOT START")
                .font(PyxisTypography.title)
                .foregroundStyle(PyxisColors.text)

            Text("LOCAL CLOSET STORAGE COULD NOT BE OPENED")
                .font(PyxisTypography.body)
                .foregroundStyle(PyxisColors.secondaryText)
                .multilineTextAlignment(.center)

            Text("YOUR LOCAL CLOSET WAS NOT DELETED OR RESET. TRY AGAIN; IF THE PROBLEM CONTINUES, CLOSE PYXIS AND CONTACT SUPPORT.")
                .font(PyxisTypography.body)
                .foregroundStyle(PyxisColors.inactiveText)
                .multilineTextAlignment(.center)
                .padding(.top, PyxisSpacing.sm)

            Button("TRY AGAIN", action: retryAction)
                .buttonStyle(MinimalButtonStyle())
                .accessibilityLabel("Retry opening local closet storage")
        }
        .padding(PyxisSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PyxisColors.background)
    }
}
