// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "sdk-spec",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "SDKSpecSteps", targets: ["SDKSpecSteps"]),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .target(
            name: "SDKSpecSteps",
            dependencies: [.product(name: "FlagsmithClient", package: "sdk")],
            path: ".",
            exclude: ["Dockerfile"],
            sources: ["steps.swift"]
        ),
    ]
)
