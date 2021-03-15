// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "API",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "API", targets: ["API"])
    ],
    dependencies: [
        .package(url: "https://github.com/vmanot/Compute.git", .branch("master")),
        .package(url: "https://github.com/vmanot/Merge.git", .branch("master")),
        .package(url: "https://github.com/vmanot/Swallow.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "API",
            dependencies: [
                "Compute",
                "Merge",
                "Swallow"
            ],
            path: "Sources"
        ),
    ]
)
