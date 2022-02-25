// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftDraw",
	  platforms: [
	       .macOS(.v10_12), .iOS(.v10),
	    ],
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
			exclude: exclude()),
        .target(
            name: "CommandLine",
            dependencies: ["SwiftDraw"],
            path: "CommandLine"),
        .testTarget(
            name: "SwiftDrawTests",
            dependencies: ["SwiftDraw"],
            path: "SwiftDrawTests")
    ]
)

func exclude() -> [String] {
#if os(Linux)
    [
        "CGPath+Segment.swift",
        "Renderer.CoreGraphics.swift",
        "Image+CoreGraphics.swift",
        "NSImage+Image.swift",
        "UIImage+Image.swift",
        "CGPattern+Closure.swift",
        "CGImage+Mask.swift"
    ]
#else
    []
#endif
}
