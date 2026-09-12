// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XQXCUITestSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "XQXCUITestSupport", targets: ["XQXCUITestSupport"]),
        .library(name: "XQNetworkStubbing", targets: ["XQNetworkStubbing"])
    ],
    targets: [
        .target(name: "XQNetworkStubbing"),
        .target(name: "XQXCUITestSupport", dependencies: ["XQNetworkStubbing"]),
        .testTarget(
            name: "XQXCUITestSupportTests",
            dependencies: ["XQXCUITestSupport", "XQNetworkStubbing"]
        )
    ]
)
