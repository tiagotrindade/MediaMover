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
            name: "MediaMover",
            path: "MediaMover", // CORREÇÃO: Aponta explicitamente para a pasta com o código
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
