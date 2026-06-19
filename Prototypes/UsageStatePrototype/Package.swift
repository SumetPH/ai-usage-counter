// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UsageStatePrototype",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "usage-prototype", targets: ["UsagePrototype"]),
    ],
    targets: [
        .executableTarget(name: "UsagePrototype")
    ],
    swiftLanguageModes: [.v5]
)
