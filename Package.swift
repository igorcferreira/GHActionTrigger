// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GHActionTrigger",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GHActionTrigger",
            targets: ["GHActionTrigger"]
        ),
        .executable(
            name: "ghaction",
            targets: ["GHActionTriggerCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GHActionTrigger",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "GHActionTriggerCLI",
            dependencies: [
                .byName(name: "GHActionTrigger"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GHActionTriggerTests",
            dependencies: ["GHActionTrigger"]
        ),
    ]
)
