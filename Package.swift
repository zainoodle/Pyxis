// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ARCHIVE",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "ArchiveCore", targets: ["ArchiveCore"])
    ],
    targets: [
        .target(
            name: "ArchiveCore",
            path: "ARCHIVE",
            exclude: [
                "App",
                "DesignSystem",
                "Services/DebugClosetSeedService.swift",
                "ViewModels",
                "Views"
            ]
        ),
        .testTarget(
            name: "ArchiveTests",
            dependencies: ["ArchiveCore"],
            path: "Tests/ArchiveTests"
        )
    ]
)
