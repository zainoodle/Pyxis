// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ARCHIVE",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ARCHIVE", targets: ["ARCHIVE"]),
        .library(name: "ArchiveCore", targets: ["ArchiveCore"])
    ],
    targets: [
        .target(
            name: "ArchiveCore",
            path: "ARCHIVE",
            exclude: [
                "App",
                "DesignSystem",
                "ViewModels",
                "Views"
            ]
        ),
        .executableTarget(
            name: "ARCHIVE",
            dependencies: ["ArchiveCore"],
            path: "ARCHIVE",
            exclude: [
                "Models",
                "Persistence",
                "Services",
                "Utilities"
            ]
        ),
        .testTarget(
            name: "ArchiveTests",
            dependencies: ["ArchiveCore"],
            path: "Tests/ArchiveTests"
        )
    ]
)
