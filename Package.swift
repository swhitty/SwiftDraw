// swift-tools-version:6.0

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
            dependencies: [],
            path: "SwiftDraw",
            swiftSettings: .upcomingFeatures
        ),
        .executableTarget(
            name: "CommandLine",
            dependencies: ["SwiftDraw"],
            path: "CommandLine",
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
            .enableUpcomingFeature("ExistentialAny"),
            .swiftLanguageMode(.v6)
        ]
    }
}
