// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FlagsmithClient",
    products: [
        .library(name: "FlagsmithClient", targets: ["FlagsmithClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0")
    ],
    targets: [
        .target(
            name: "FlagsmithClient",
            dependencies: [],
            path: "FlagsmithClient/Classes",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]),
        .testTarget(
            name: "FlagsmitClientTests",
            dependencies: ["FlagsmithClient"],
            path: "FlagsmithClient/Tests"),
    ]
)
