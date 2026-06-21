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
        // Concrete implementations of Domain protocols, DTOs, and mappers.
        // The only layer that knows about URLSession, persistence, etc.
        // NOT MainActor-isolated by default: networking/persistence should run
        // off the main actor. Factory registrations live in the DI package.
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Common", package: "Common"),
                .product(name: "Model", package: "Model"),
                .product(name: "Domain", package: "Domain"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
