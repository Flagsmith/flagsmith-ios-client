// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FlagsmithClient",
    products: [
        .library(name: "FlagsmithClient", targets: ["FlagsmithClient"]),
    ],
    targets: [
        .target(
            name: "FlagsmithClient",
            dependencies: [],
            path: "FlagsmithClient/Classes"),
        .testTarget(
            name: "FlagsmitClientTests",
            dependencies: ["FlagsmithClient"],
            path: "FlagsmithClient/Tests"),
    ]
)
