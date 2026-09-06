// swift-tools-version: 6.3
import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let presentationSwiftSettings: [SwiftSetting] = sharedSwiftSettings + [
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "AppModules",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "DI", targets: ["DI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "Common",
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "Model",
            dependencies: ["Common"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "Domain",
            dependencies: ["Common", "Model"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "Data",
            dependencies: ["Common", "Model", "Domain"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "DI",
            dependencies: [
                "Common", "Model", "Domain", "Data",
                .product(name: "FactoryKit", package: "Factory"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "Presentation",
            dependencies: ["Common", "Model", "Domain", "DI"],
            resources: [.process("Resources")],
            swiftSettings: presentationSwiftSettings
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain", "Model"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "DataTests",
            dependencies: ["Data", "Domain", "Model"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: [
                "Presentation", "Domain", "Model", "DI",
                .product(name: "FactoryTesting", package: "Factory"),
            ],
            swiftSettings: presentationSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
