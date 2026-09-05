// swift-tools-version: 6.3
import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "Data",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "Data", targets: ["Data"]),
    ],
    dependencies: [
        .package(path: "../Common"),
        .package(path: "../Model"),
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Common", package: "Common"),
                .product(name: "Model", package: "Model"),
                .product(name: "Domain", package: "Domain"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "DataTests",
            dependencies: ["Data", .product(name: "Domain", package: "Domain"), .product(name: "Model", package: "Model")],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
