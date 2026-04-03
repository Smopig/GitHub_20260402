// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RightClickHeroKit",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "RightClickHeroKit", targets: ["RightClickHeroKit"]),
    ],
    targets: [
        .target(
            name: "RightClickHeroKit",
            path: "Sources/RightClickHeroKit",
            resources: [
                .copy("FileTemplates"),
            ]
        ),
    ]
)
