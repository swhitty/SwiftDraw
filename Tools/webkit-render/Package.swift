// swift-tools-version:6.2

// Private, macOS-only dev tool: renders SVGs to PNGs with WebKit (Safari's engine).
// One of the three renderers swiftdraw-diff runs and compares; it does not depend on SwiftDraw.
//
//   swift build -c release --package-path Tools/webkit-render
//   Tools/webkit-render/.build/release/webkit-render in.svg out.png --size 64x64 --scale 2
//   Tools/webkit-render/.build/release/webkit-render --jobs jobs.json --out dir
//
// Needs a logged-in GUI session (WebKit needs the window server).

import PackageDescription

let package = Package(
    name: "webkit-render",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "webkit-render", targets: ["webkit-render"])
    ],
    targets: [
        .target(name: "WebKitRenderCore", swiftSettings: .upcomingFeatures),
        .executableTarget(
            name: "webkit-render",
            dependencies: ["WebKitRenderCore"],
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "WebKitRenderCoreTests",
            dependencies: ["WebKitRenderCore"],
            swiftSettings: .upcomingFeatures
        )
    ]
)

extension Array where Element == SwiftSetting {
    static var upcomingFeatures: [SwiftSetting] {
        [
            // Actor isolation
            .defaultIsolation(nil),

            // Concurrency
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),

            // Language
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("ImmutableWeakCaptures"),

            // Module boundaries
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("InternalImportsByDefault"),

            .swiftLanguageMode(.v6)
        ]
    }
}
