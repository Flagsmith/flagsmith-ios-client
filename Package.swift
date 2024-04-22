// swift-tools-version:5.9

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
            path: "FlagsmithClient/Classes",
            resources: [
                .copy("PrivacyInfo.xcprivacy"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete"),
                .enableUpcomingFeature("ExistentialAny"), // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
            ]),
        .testTarget(
            name: "FlagsmitClientTests",
            dependencies: ["FlagsmithClient"],
            path: "FlagsmithClient/Tests")
    ]
)
