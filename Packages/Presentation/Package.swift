// swift-tools-version: 6.3
import PackageDescription

// Base settings shared with the other layers.
let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

// Presentation runs on the main actor by default: it's all SwiftUI Views and
// @Observable ViewModels, so MainActor isolation is the right default here.
let presentationSwiftSettings: [SwiftSetting] = sharedSwiftSettings + [
    .defaultIsolation(MainActor.self),
]

let package = Package(
    name: "Presentation",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    dependencies: [
        .package(path: "../Common"),
        .package(path: "../Model"),
        .package(path: "../Domain"),
        .package(path: "../DI"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.0.0"),
    ],
    targets: [
        // Views and ViewModels. ViewModels inject Domain protocols via the
        // Container keyPaths declared in DI. Presentation depends on DI (not Data),
        // so it sees the registrations without ever importing concrete Data types.
        // MainActor-isolated by default (see presentationSwiftSettings).
        .target(
            name: "Presentation",
            dependencies: [
                .product(name: "Common", package: "Common"),
                .product(name: "Model", package: "Model"),
                .product(name: "Domain", package: "Domain"),
                .product(name: "DI", package: "DI"),
            ],
            swiftSettings: presentationSwiftSettings
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: [
                "Presentation",
                .product(name: "Domain", package: "Domain"),
                .product(name: "Model", package: "Model"),
                .product(name: "DI", package: "DI"),
                .product(name: "FactoryTesting", package: "Factory"),
            ],
            swiftSettings: presentationSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
