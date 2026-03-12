// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PhotoMoveApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PhotoMoveApp", targets: ["PhotoMoveApp"])
    ],
    targets: [
        .executableTarget(
            name: "PhotoMoveApp",
            path: "Sources/PhotoMoveApp",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
