// swift-tools-version:5.3

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
    ]
)
