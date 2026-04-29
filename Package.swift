// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "clipboard",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "clipboard",
            targets: ["App"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .target(name: "Clipper"),
                .target(name: "UI"),
                .target(name: "Utils"),
                .product(name: "HotKey", package: "HotKey"),
            ]
        ),
        .target(name: "Clipper", dependencies: [.target(name: "Utils")]),
        .target(name: "UI", dependencies: [.target(name: "Clipper")]),
        .target(name: "Utils"),
    ]
)
