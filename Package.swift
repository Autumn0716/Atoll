// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AtollMediaRemoteSupport",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MediaRemoteSupportCore", targets: ["MediaRemoteSupportCore"])
    ],
    targets: [
        .target(
            name: "MediaRemoteSupportCore",
            path: "DynamicIsland/MediaControllers/MediaRemoteSupportCore"
        ),
        .testTarget(
            name: "MediaRemoteSupportCoreTests",
            dependencies: ["MediaRemoteSupportCore"],
            path: "Tests/MediaRemoteSupportCoreTests"
        )
    ]
)
