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
    dependencies: [],
    targets: [
        .target(
            name: "PhotoSealCore",
            dependencies: [],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PhotoSealCoreTests",
            dependencies: ["PhotoSealCore"]
        ),
    ]
)
