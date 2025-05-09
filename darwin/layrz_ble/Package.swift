// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "layrz_ble",
    platforms: [
        .macOS("11.0"),
        .iOS("14.0"),
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