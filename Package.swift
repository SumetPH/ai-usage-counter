// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacAiUsage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacAiUsageCore", targets: ["MacAiUsageCore"]),
        .executable(name: "MacAiUsage", targets: ["MacAiUsageApp"]),
    ],
    targets: [
        .target(name: "MacAiUsageCore"),
        .executableTarget(
            name: "MacAiUsageApp",
            dependencies: ["MacAiUsageCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MacAiUsageCoreTests",
            dependencies: ["MacAiUsageCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
