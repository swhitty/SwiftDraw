// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
// - SR-631: requires swift 5.0-dev (Xcode 10.2 Beta) toolchain to build. (https://swift.org/download/#snapshots)
// % export TOOLCHAINS=swift

import PackageDescription

let exclude: [String]
#if os(Linux)
	exclude = [
		"CGPath+Segment.swift",
		"Renderer.CoreGraphics.swift",
        "Image+CoreGraphics.swift",
        "NSImage+Image.swift",
        "UIImage+Image.swift",
        "CGRendererTests.swift",
        "CGRenderer.PathTests.swift",
        "ParserSVGImageTests.swift",
        "UIImage+ImageTests.swift",
        "NSImage+ImageTests.swift",
        "NSBitmapImageRep+Extensions.swift",
        "Renderer.CoreGraphicsTypesTests.swift",
        "Renderer.LayerTreeProviderTests.swift",
        "Parser.XML.ImageTests.swift",
        "CGPath+SegmentTests.swift",
        "CGPattern+Closure.swift",
        "CGImage+Mask.swift",
        "ImageTests.swift"
	]
#else
	exclude = [
        "UIImage+Image.swift",
        "CGRenderer.PathTests.swift",
        "ParserSVGImageTests.swift",
        "UIImage+ImageTests.swift",
        "NSImage+ImageTests.swift"
    ]
#endif

let package = Package(
    name: "SwiftDraw",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(name: "swiftdraw", targets: ["CommandLine"]),
		.library(
            name: "SwiftDraw",
            targets: ["SwiftDraw"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftDraw",
            dependencies: [],
			path: "SwiftDraw",
			exclude: exclude),
        .target(
            name: "CommandLine",
            dependencies: ["SwiftDraw"],
            path: "CommandLine"),
        .testTarget(
            name: "SwiftDrawTests",
            dependencies: ["SwiftDraw"],
            path: "SwiftDrawTests",
			exclude: exclude)
    ]
)
