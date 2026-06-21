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
    name: "DI",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "DI", targets: ["DI"]),
    ],
    dependencies: [
        .package(path: "../Common"),
        .package(path: "../Model"),
        .package(path: "../Domain"),
        .package(path: "../Data"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.0.0"),
    ],
    targets: [
        // Composition root. The ONLY place that imports Factory for registration.
        // Imports every layer, binds Domain protocols to Data implementations, and
        // exposes the Container keyPaths that Presentation injects against.
        //
        // Registrations live under Sources/DI/Registrations, one file per feature,
        // so the wiring scales as the app grows.
        .target(
            name: "DI",
            dependencies: [
                .product(name: "Common", package: "Common"),
                .product(name: "Model", package: "Model"),
                .product(name: "Domain", package: "Domain"),
                .product(name: "Data", package: "Data"),
                .product(name: "FactoryKit", package: "Factory"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
