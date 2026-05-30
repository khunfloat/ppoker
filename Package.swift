// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PPoker",
    platforms: [.iOS(.v16), .macOS(.v15)],
    products: [
        .library(name: "PPokerEngine", targets: ["PPokerEngine"]),
        .library(name: "PPokerNetworking", targets: ["PPokerNetworking"]),
        .library(name: "PPokerStats", targets: ["PPokerStats"]),
        .library(name: "PPokerUI", targets: ["PPokerUI"]),
        .executable(name: "PPokerSmoke", targets: ["PPokerSmoke"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "PPokerEngine",
            path: "Sources/PPokerEngine"
        ),
        .target(
            name: "PPokerNetworking",
            dependencies: ["PPokerEngine"],
            path: "Sources/PPokerNetworking"
        ),
        .target(
            name: "PPokerStats",
            dependencies: [
                "PPokerEngine",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/PPokerStats"
        ),
        .target(
            name: "PPokerUI",
            dependencies: ["PPokerEngine", "PPokerNetworking", "PPokerStats"],
            path: "Sources/PPokerUI"
        ),
        .executableTarget(
            name: "PPokerSmoke",
            dependencies: ["PPokerEngine", "PPokerNetworking", "PPokerStats"],
            path: "Sources/PPokerSmoke"
        ),
        .testTarget(
            name: "PPokerEngineTests",
            dependencies: ["PPokerEngine"],
            path: "Tests/PPokerEngineTests"
        ),
        .testTarget(
            name: "PPokerNetworkingTests",
            dependencies: ["PPokerNetworking"],
            path: "Tests/PPokerNetworkingTests"
        ),
        .testTarget(
            name: "PPokerUITests",
            dependencies: [
                "PPokerUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/PPokerUITests"
        ),
    ]
)
