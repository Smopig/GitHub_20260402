// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RightClickHeroKit",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "RightClickHeroKit", targets: ["RightClickHeroKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "RightClickHeroKit",
            dependencies: [
                .product(name: "SSZipArchive", package: "ZipArchive"),
            ],
            path: "Sources/RightClickHeroKit",
            resources: [
                .copy("FileTemplates"),
            ]
        ),
    ]
)
