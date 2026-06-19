// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MenuBarUIPrototype",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "menubar-ui-prototype", targets: ["MenuBarUIPrototype"]),
    ],
    targets: [
        .executableTarget(name: "MenuBarUIPrototype")
    ],
    swiftLanguageModes: [.v5]
)
