// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FlagsmithClient",
    products: [
        .library(name: "FlagsmithClient", targets: ["FlagsmithClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.53.8")
    ],
    targets: [
        .target(
            name: "FlagsmithClient",
            dependencies: [],
            path: "FlagsmithClient/Classes"
            // plugins: [
            //     .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
            ),
        .testTarget(
            name: "FlagsmitClientTests",
            dependencies: ["FlagsmithClient"],
            path: "FlagsmithClient/Tests")
        // .binaryTarget(
        //     name: "swiftformat",
        //     url: "https://github.com/nicklockwood/SwiftFormat/releases/download/0.53.8/swiftformat.artifactbundle.zip",
        //     checksum: "12c4cd6e1382479cd38bba63c81eb50121f9b2212a8b1f8f5fa9ed1d1c6d07d1"
        // ),
    ]
)
