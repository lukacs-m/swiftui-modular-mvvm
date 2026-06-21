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
    name: "Domain",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    dependencies: [
        .package(path: "../Common"),
        .package(path: "../Model"),
    ],
    targets: [
        // Business logic, use cases, and the repository protocol abstractions.
        // Pure Swift — knows nothing about Factory, networking, persistence, or UI.
        // NOT MainActor-isolated by default: domain logic should stay actor-agnostic.
        .target(
            name: "Domain",
            dependencies: [
                .product(name: "Common", package: "Common"),
                .product(name: "Model", package: "Model"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        // Tests construct use cases directly with mock repositories — no container,
        // so no Factory dependency here either.
        .testTarget(
            name: "DomainTests",
            dependencies: [
                "Domain",
                .product(name: "Model", package: "Model"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
