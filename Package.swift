// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftAPI",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SwiftAPI",
            targets: [
                "SwiftAPI"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vmanot/Merge.git", branch: "master"),
        .package(url: "https://github.com/vmanot/Swallow.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "SwiftAPI",
            dependencies: [
                "Merge",
                "Swallow"
            ],
            path: "Sources"
        ),
    ]
)
