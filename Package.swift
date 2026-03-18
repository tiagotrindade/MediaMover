// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FolioSort",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FolioSort", targets: ["FolioSort"])
    ],
    targets: [
        .executableTarget(
            name: "FolioSort",
            path: "Sources/PhotoMoveApp",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
