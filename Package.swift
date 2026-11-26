// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RCProxy",
    platforms: [
        .iOS(.v17), .tvOS(.v17), .macOS(.v14)
    ],
    products: [
        // The in-app requests logger, for iOS and tvOS apps.
        .library(
            name: "RCProxy",
            targets: ["RCProxy"]),
        // The model and the network link shared with viewers such as RCProxy Desktop (iOS, tvOS and macOS).
        .library(
            name: "RCProxyCore",
            targets: ["RCProxyCore"]),
    ],
    targets: [
        .target(
            name: "RCProxyCore"
        ),
        .target(
            name: "RCProxy",
            dependencies: ["RCProxyCore"]
        ),
        .testTarget(
            name: "RCProxyCoreTests",
            dependencies: ["RCProxyCore"]),
        .testTarget(
            name: "RCProxyTests",
            dependencies: ["RCProxy"]),
    ],
    swiftLanguageModes: [.v6]
)
