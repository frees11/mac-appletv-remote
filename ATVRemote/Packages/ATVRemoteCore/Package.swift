// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ATVRemoteCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "ATVRemoteCore",
            targets: ["ATVRemoteCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.25.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        .package(url: "https://github.com/attaswift/BigInt", from: "5.3.0"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "ATVRemoteCore",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "BigInt"),
            ]
        ),
        .testTarget(
            name: "ATVRemoteCoreTests",
            dependencies: [
                "ATVRemoteCore",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ]
        ),
    ]
)
