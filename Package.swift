// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Pyxis",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PyxisCore", targets: ["PyxisCore"])
    ],
    targets: [
        .target(
            name: "PyxisCore",
            path: "src",
            exclude: [
                "main",
                "design-system",
                "services/DebugClosetSeedService.swift",
                "views"
            ]
        ),
        .testTarget(
            name: "PyxisTests",
            dependencies: ["PyxisCore"],
            path: "tests/PyxisTests"
        )
    ]
)
