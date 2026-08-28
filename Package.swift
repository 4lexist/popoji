// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Popoji",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Popoji", targets: ["Popoji"])
    ],
    targets: [
        .executableTarget(
            name: "Popoji",
            path: "Sources/Popoji"
        )
    ]
)
