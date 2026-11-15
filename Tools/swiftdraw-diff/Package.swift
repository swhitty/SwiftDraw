// swift-tools-version:6.2

// Private, macOS-only dev tool: renders SVGs with SwiftDraw and writes an
// "eyeball" page comparing them with the browser's own live rendering.
//
//   cd Tools/swiftdraw-diff
//   swift run -c release swiftdraw-diff ../../Samples.bundle --out .build/report
//   open .build/report/index.html
//
// index.html is self-contained (assets embedded as data: URIs), so it opens
// from file:// in Safari or Chrome and the in-page pixel diff needs no server.
// --hide-below <percent> sets the default diff threshold for hiding rows (default 1).
//
// Regression check before merging (base defaults to main, head to the working copy):
//
//   swift run -c release swiftdraw-diff compare --base main ../../Samples.bundle
//
// Builds SwiftDraw at --base in a reusable git worktree (.build/compare/base-src),
// renders both, scores each against WebKit and prints regressed / improved /
// changed files. Exits 1 if any file got further from WebKit by more than
// --tolerance percentage points (default 0.5). --head <ref> compares two commits.
// --webkit additionally snapshots each SVG with an offscreen WKWebView (experimental).

import PackageDescription

let package = Package(
    name: "swiftdraw-diff",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(name: "SwiftDraw", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "swiftdraw-diff",
            dependencies: [.product(name: "SwiftDraw", package: "SwiftDraw")]
        )
    ],
    swiftLanguageModes: [.v5]
)
