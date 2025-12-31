// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PhotoSeal",
    platforms: [
        .iOS(.v17),
    ],
    dependencies: [
        .package(url: "https://github.com/contentauth/c2pa-ios.git", from: "0.0.1"),
    ],
    products: [
        .library(
            name: "PhotoSealCore",
            targets: ["PhotoSealCore"]
        ),
    ],
    targets: [
        .target(
            name: "PhotoSealCore",
            dependencies: [
                .product(name: "C2PA", package: "c2pa-ios"),
            ]
        ),
        .testTarget(
            name: "PhotoSealCoreTests",
            dependencies: ["PhotoSealCore"]
        ),
    ]
)
