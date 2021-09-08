import PackageDescription

let package = Package(
    name: "FlagsmithClient",
    products: [
        .library(name: "FlagsmithClient", targets: ["FlagsmithClient"]),
    ],
    targets: [
        .target(
            name: "FlagsmithClient",
            dependencies: []),
    ]
)
