// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwiftDraw",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
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
