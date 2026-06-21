// swift-tools-version: 6.3
import PackageDescription

// Shared Swift settings applied to every layer package.
// - Language mode 6 (via `swiftLanguageModes`).
// - Upcoming features pulled forward from later Swift evolution so the codebase
//   is written against the stricter, future-default semantics today.
let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),              // require `any` on existentials
    .enableUpcomingFeature("InternalImportsByDefault"),   // imports are internal unless `public import`
    .enableUpcomingFeature("MemberImportVisibility"),     // must import the module a member comes from
    .enableUpcomingFeature("InferIsolatedConformances"),  // isolated conformance inference
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"), // nonisolated async fns run on caller's actor
]

let package = Package(
    name: "Common",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "Common", targets: ["Common"]),
    ],
    targets: [
        // Shared utilities, ViewState, logging. Depends on nothing internal.
        .target(
            name: "Common",
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
