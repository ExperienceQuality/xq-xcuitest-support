// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XQXCUITestSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "XQXCUITestSupport", targets: ["XQXCUITestSupport"])
    ],
    targets: [
        .target(name: "XQXCUITestSupport"),
        .testTarget(name: "XQXCUITestSupportTests", dependencies: ["XQXCUITestSupport"])
    ]
)
