// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "layrz_ble",
    platforms: [
        .iOS("14.0"),
        .macOS("11.0")
    ],
    products: [
        .library(name: "layrz-ble", targets: ["layrz_ble"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "layrz_ble",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)