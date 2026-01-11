// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "kswitch",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .executableTarget(
            name: "kswitch",
            path: "Sources/kswitch",
            resources: [
                .process("Resources"),
            ])
    ]
)
