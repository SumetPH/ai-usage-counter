// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AIUsageCounter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AIUsageCounterCore", targets: ["AIUsageCounterCore"]),
        .executable(name: "ai-usage-counter", targets: ["AIUsageCounterApp"]),
    ],
    targets: [
        .target(name: "AIUsageCounterCore"),
        .executableTarget(
            name: "AIUsageCounterApp",
            dependencies: ["AIUsageCounterCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AIUsageCounterCoreTests",
            dependencies: ["AIUsageCounterCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
