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
            path: "Pyxis",
            exclude: [
                "App",
                "Assets.xcassets",
                "DesignSystem",
                "PrivacyInfo.xcprivacy",
                "Services/DebugClosetSeedService.swift",
                "Views"
            ]
        ),
        .testTarget(
            name: "PyxisTests",
            dependencies: ["PyxisCore"],
            path: "Tests/PyxisTests"
        )
    ]
)
