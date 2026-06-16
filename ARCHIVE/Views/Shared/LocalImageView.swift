import AppKit
import SwiftUI

struct LocalImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .overlay {
                        Text("NO IMAGE")
                            .font(ArchiveTypography.label)
                            .foregroundStyle(ArchiveColors.inactiveText)
                    }
            }
        }
        .accessibilityLabel("Clothing image")
    }
}
