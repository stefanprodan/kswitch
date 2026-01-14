// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KSwitch",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "KSwitch", targets: ["KSwitch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
        .package(url: "https://github.com/Kolos65/Mockable.git", from: "0.5.0"),
    ],
    targets: [
        // Domain - pure business logic, protocols marked @Mockable
        .target(
            name: "Domain",
            dependencies: [
                .product(name: "Mockable", package: "Mockable"),
            ],
            path: "Sources/Domain",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .define("MOCKING", .when(configuration: .debug)),
            ]
        ),

        // Infrastructure - implements Domain protocols
        .target(
            name: "Infrastructure",
            dependencies: [
                "Domain",
                .product(name: "Mockable", package: "Mockable"),
            ],
            path: "Sources/Infrastructure",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .define("MOCKING", .when(configuration: .debug)),
            ]
        ),

        // App - SwiftUI, depends on both
        .executableTarget(
            name: "KSwitch",
            dependencies: [
                "Domain",
                "Infrastructure",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/App",
            exclude: ["entitlements.plist"],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),

        // Tests
        .testTarget(
            name: "DomainTests",
            dependencies: [
                "Domain",
                .product(name: "Mockable", package: "Mockable"),
            ],
            path: "Tests/DomainTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("Testing"),
                .define("MOCKING"),
            ]
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: [
                "Infrastructure",
                "Domain",
                .product(name: "Mockable", package: "Mockable"),
            ],
            path: "Tests/InfrastructureTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("Testing"),
                .define("MOCKING"),
            ]
        ),
    ]
)
