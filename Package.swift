// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PhotoSeal",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PhotoSealCore",
            targets: ["PhotoSealCore"]
        ),
    ],
    targets: [
        .target(
            name: "PhotoSealCore"
        ),
        .testTarget(
            name: "PhotoSealCoreTests",
            dependencies: ["PhotoSealCore"]
        ),
    ]
)
