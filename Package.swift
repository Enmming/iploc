// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IPLoc",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "IPLocCore", targets: ["IPLocCore"]),
        .executable(name: "IPLoc", targets: ["IPLocApp"]),
    ],
    targets: [
        .target(
            name: "IPLocCore"
        ),
        .executableTarget(
            name: "IPLocApp",
            dependencies: ["IPLocCore"]
        ),
        .testTarget(
            name: "IPLocCoreTests",
            dependencies: ["IPLocCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
