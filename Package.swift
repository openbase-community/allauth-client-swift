// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AllAuthClientSwift",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "AllAuthClientSwift",
            targets: ["AllAuthClientSwift"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2"),
    ],
    targets: [
        .target(
            name: "AllAuthClientSwift",
            dependencies: ["SwiftyJSON"]
        ),
        .testTarget(
            name: "AllAuthClientSwiftTests",
            dependencies: ["AllAuthClientSwift"]
        ),
    ]
)
