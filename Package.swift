// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "API",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "API", targets: ["API"])
    ],
    dependencies: [
        .package(url: "git@github.com:vmanot/CombineX.git", .branch("master")),
        .package(url: "git@github.com:vmanot/Concurrency.git", .branch("master")),
        .package(url: "git@github.com:vmanot/Network.git", .branch("master")),
        .package(url: "git@github.com:vmanot/Swallow.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "API",
            dependencies: ["CombineX", "Concurrency", "Network", "Swallow"],
            path: "Sources"
        ),
    ],
    swiftLanguageVersions: [
        .version("5.1")
    ]
)
