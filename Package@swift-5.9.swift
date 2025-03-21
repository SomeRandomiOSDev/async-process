// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "async-process",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "AsyncProcess",
            targets: ["AsyncProcess"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "AsyncProcess",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
