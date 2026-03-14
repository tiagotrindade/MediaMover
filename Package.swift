// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MediaMover",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MediaMover", targets: ["MediaMover"])
    ],
    targets: [
        .executableTarget(
            name: "MediaMover", // O código fonte está agora em "MediaMover/"
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
