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
        .target(name: "WebKitRenderCore"),
        .executableTarget(
            name: "webkit-render",
            dependencies: ["WebKitRenderCore"]
        ),
        .testTarget(
            name: "WebKitRenderCoreTests",
            dependencies: ["WebKitRenderCore"]
        )
    ]
)
