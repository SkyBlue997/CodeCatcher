// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeCatcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodeCatcher", targets: ["CodeCatcher"])
    ],
    dependencies: [
        // 没有外部依赖
    ],
    targets: [
        .executableTarget(
            name: "CodeCatcher",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Assets.xcassets"),
                .process("Localizations")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"])
            ]
        )
    ]
)
