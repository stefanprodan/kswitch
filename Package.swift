// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "kswitch",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "kswitch",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/kswitch",
            resources: [
                .process("Resources"),
            ]
        )
    ]
)
