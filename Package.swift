// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-json-path",
    platforms: [
        .macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "JSONPath", targets: ["JSONPath"]),
    ],
    targets: [
        .target(name: "JSONPath"),
        .testTarget(
            name: "JSONPathTests",
            dependencies: ["JSONPath"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
