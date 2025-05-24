// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftDraw",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1)
    ],
    products: [
        .executable(name: "swiftdrawcli", targets: ["CommandLine"]),
        .library(
            name: "SwiftDraw",
            targets: ["SwiftDraw"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftDraw",
            dependencies: ["DOM"],
            path: "SwiftDraw",
            swiftSettings: .upcomingFeatures
        ),
        .target(
            name: "DOM",
            dependencies: [],
            path: "DOM/Sources"
        ),
        .executableTarget(
            name: "CommandLine",
            dependencies: ["SwiftDraw"],
            path: "CommandLine",
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "DOMTests",
            dependencies: ["DOM"],
            path: "DOM/Tests",
            resources: [
                .copy("Test.bundle")
            ],
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "SwiftDrawTests",
            dependencies: ["SwiftDraw"],
            path: "SwiftDrawTests",
            resources: [
                .copy("Test.bundle")
            ],
            swiftSettings: .upcomingFeatures
        )
    ]
)

extension Array where Element == SwiftSetting {

    static var upcomingFeatures: [SwiftSetting] {
        [
            .enableUpcomingFeature("ExistentialAny")
        ]
    }
}
