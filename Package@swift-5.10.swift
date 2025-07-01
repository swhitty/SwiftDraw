// swift-tools-version:5.10

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
            dependencies: ["SwiftDrawDOM"],
            path: "SwiftDraw/Sources",
            swiftSettings: .upcomingFeatures
        ),
        .target(
            name: "SwiftDrawDOM",
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
            name: "SwiftDrawDOMTests",
            dependencies: ["SwiftDrawDOM"],
            path: "DOM/Tests",
            resources: [
                .copy("Test.bundle")
            ],
            swiftSettings: .upcomingFeatures
        ),
        .testTarget(
            name: "SwiftDrawTests",
            dependencies: ["SwiftDraw"],
            path: "SwiftDraw/Tests",
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
