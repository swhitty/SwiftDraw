// swift-tools-version:6.2

// Private, macOS-only dev tool: scores SwiftDraw's rendering against WebKit and, optionally, resvg.
// It runs three SVG → PNG renderers and diffs their PNGs:
//
//   swiftdrawcli   built from this repo at each SwiftDraw revision (cached by commit)
//   webkit-render  Tools/webkit-render, built on first use; also decides each SVG's size
//   resvg          optional (--resvg), found on PATH (brew install resvg)
//
// Score SwiftDraw's working copy:
//
//   swift build -c release --package-path Tools/swiftdraw-diff
//   Tools/swiftdraw-diff/.build/release/swiftdraw-diff Samples.bundle [--resvg]
//
// Regression check before merging (base defaults to main, head to the working copy):
//
//   Tools/swiftdraw-diff/.build/release/swiftdraw-diff compare --base main Samples.bundle [--resvg]
//
// See AGENTS.md, "Checking rendering changes". Needs a logged-in GUI session (WebKit).

import PackageDescription

let package = Package(
    name: "swiftdraw-diff",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "swiftdraw-diff", targets: ["swiftdraw-diff"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", .upToNextMinor(from: "1.0.2"))
    ],
    targets: [
        .target(name: "SwiftDrawDiffCore", swiftSettings: .upcomingFeatures),
        .executableTarget(
            name: "swiftdraw-diff",
            dependencies: [
                "SwiftDrawDiffCore",
                .product(name: "Subprocess", package: "swift-subprocess")
            ],
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "SwiftDrawDiffCoreTests",
            dependencies: ["SwiftDrawDiffCore"],
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
