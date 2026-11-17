//
//  CommandLine.ConfigurationTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 7/12/18.
//  Copyright 2020 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation
import Testing
@testable import SwiftDraw

struct CommandLineConfigurationTests {

    @Test(
        arguments: [
            ("file", "/test", "/test/file"),
            ("file", "/test/subfolder", "/test/subfolder/file"),
            ("../file", "/test/subfolder", "/test/file"),
        ] as [(String, String, String)]
    )
    func parseFileURLResolvesAgainstDirectory(file: String, directory: String, expected: String) throws {
        let url = try CommandLine.parseFileURL(file: file, within: URL(directory: directory))
        #expect(url == URL(fileURLWithPath: expected))
    }

    @Test
    func newURLForFormat() {
        let svg = URL(fileURLWithPath: "/test/file.svg")
        #expect(svg.newURL(for: .jpeg, scale: .default) == URL(fileURLWithPath: "/test/file.jpg"))
        #expect(svg.newURL(for: .png, scale: .default) == URL(fileURLWithPath: "/test/file.png"))
        #expect(svg.newURL(for: .pdf, scale: .default) == URL(fileURLWithPath: "/test/file.pdf"))
        #expect(svg.newURL(for: .jpeg, scale: .retina) == URL(fileURLWithPath: "/test/file.jpg"))
        #expect(svg.newURL(for: .sfsymbol, scale: .default) == URL(fileURLWithPath: "/test/file-symbol.svg"))
        #expect(svg.newURL(for: .swift, scale: .default) == URL(fileURLWithPath: "/test/file.swift"))

        let noExtension = URL(fileURLWithPath: "/test/file")
        #expect(noExtension.newURL(for: .jpeg, scale: .default) == URL(fileURLWithPath: "/test/file.jpg"))
    }

    @Test
    func parseConfigurationDefaults() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "pdf")

        #expect(config.input == URL(fileURLWithPath: "/file.svg"))
        #expect(config.output == URL(fileURLWithPath: "/file.pdf"))
        #expect(config.scale == .default)
        #expect(config.format == .pdf)
        #expect(config.size == .default)
    }

    @Test
    func parseConfigurationSize() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "png", "--size", "400x300")

        #expect(config.input == URL(fileURLWithPath: "/file.svg"))
        #expect(config.output == URL(fileURLWithPath: "/file.png"))
        #expect(config.format == .png)
        #expect(config.size == .custom(width: 400, height: 300))
    }

    @Test
    func parseConfigurationScale2x() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "png", "--scale", "2x")

        #expect(config.input == URL(fileURLWithPath: "/file.svg"))
        #expect(config.output == URL(fileURLWithPath: "/file@2x.png"))
        #expect(config.scale == .retina)
        #expect(config.format == .png)
    }

    @Test
    func parseConfigurationScale3x() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "png", "--scale", "3x")

        #expect(config.output == URL(fileURLWithPath: "/file@3x.png"))
        #expect(config.scale == .superRetina)
    }

    @Test
    func parseConfigurationLogLevel() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "pdf")
        #expect(config.logLevel == .info)

        let quiet = try parseConfiguration("swiftdraw", "file.svg", "--format", "pdf", "--quiet")
        #expect(quiet.logLevel == .error)
    }

    @Test(
        arguments: [
            [],
            ["swiftdraw", "file.svg"],
            ["swiftdraw", "file.svg", "--format", "unknown"],
            ["swiftdraw", "file.svg", "--format", "swift", "--precision", "abc"],
            ["swiftdraw", "file.svg", "--format", "png", "--size", "abc"],
            ["swiftdraw", "file.svg", "--format", "png", "--size", "0x0"],
            ["swiftdraw", "file.svg", "--format", "png", "--size", "-10x20"],
            ["swiftdraw", "file.svg", "--format", "png", "--scale", "5x"],
            ["swiftdraw", "file.svg", "--format", "swift", "--api", "flutter"],
            ["swiftdraw", "file.svg", "--format", "sfsymbol", "--size", "tiny"],
            ["swiftdraw", "file.svg", "--format", "sfsymbol", "--ultralight-stroke-width", "abc"],
            ["swiftdraw", "file.svg", "--format", "sfsymbol", "--black-stroke-width", "0"],
        ]
    )
    func invalidConfigurationThrows(args: [String]) {
        #expect(throws: CommandLine.Error.invalid) {
            try parseConfiguration(args)
        }
    }

    @Test(
        arguments: [
            ("auto", .init()),
            ("1,2,3,4", .init(top: 1, left: 2, bottom: 3, right: 4)),
            ("0.995,auto,2.5,auto", .init(top: 0.995, left: nil, bottom: 2.5, right: nil)),
        ] as [(String, CommandLine.Insets)]
    )
    func parseInsets(string: String, expected: CommandLine.Insets) throws {
        #expect(try CommandLine.parseInsets(from: string) == expected)
    }

    @Test
    func parseInsetsFromNilIsNil() throws {
        #expect(try CommandLine.parseInsets(from: nil) == nil)
    }

    @Test(arguments: ["cab,1,2,2", "1,2", ""])
    func parseInvalidInsetsThrows(string: String) {
        #expect(throws: (any Error).self) {
            try CommandLine.parseInsets(from: string)
        }
    }

    @Test
    func parseConfigurationInsets() throws {
        let config = try parseConfiguration(
            "swiftdraw",
            "file.svg",
            "--format",
            "sfsymbol",
            "--insets",
            "1,2,3.5,auto"
        )

        #expect(config.insets.top == 1)
        #expect(config.insets.left == 2)
        #expect(config.insets.bottom == 3.5)
        #expect(config.insets.right == nil)
    }

    @Test(arguments: ["appkit", "uikit", "swiftui"])
    func parseConfigurationAPI(api: String) throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "swift", "--api", api)

        #expect(config.format == .swift)
        #expect(config.api?.rawValue == api)
    }

    @Test
    func textAPIConversion() {
        #expect(CommandLine.makeTextAPI(for: nil) == .swiftUI)
        #expect(CommandLine.makeTextAPI(for: .appkit) == .appKit)
        #expect(CommandLine.makeTextAPI(for: .uikit) == .uiKit)
    }

    @Test
    func parseConfigurationPrecision() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "swift", "--precision", "3")

        #expect(config.precision == 3)
    }

    @Test
    func parseConfigurationHideUnsupportedFilters() throws {
        let config = try parseConfiguration(
            "swiftdraw",
            "file.svg",
            "--format",
            "png",
            "--hide-unsupported-filters"
        )

        #expect(config.options.contains(.hideUnsupportedFilters))
    }

    @Test
    func parseConfigurationLegacyInsets() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "sfsymbol", "--legacy")

        #expect(config.isLegacyInsetsEnabled)
    }

    @Test(arguments: ["small", "medium", "large"])
    func parseConfigurationSymbolSize(size: String) throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "sfsymbol", "--size", size)
        #expect(config.symbolSize.map { "\($0)" } == size)
    }

    @Test
    func parseConfigurationCustomOutput() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "png", "--output", "custom.png")

        #expect(config.output == URL(fileURLWithPath: "/custom.png"))
    }

    @Test
    func emptyInsets() {
        #expect(CommandLine.Insets().isEmpty)
        #expect(!CommandLine.Insets(top: 1).isEmpty)
        #expect(!CommandLine.Insets(left: 1).isEmpty)
        #expect(!CommandLine.Insets(bottom: 1).isEmpty)
        #expect(!CommandLine.Insets(right: 1).isEmpty)
    }

    @Test
    func parseConfigurationUltralightStrokeWidth() throws {
        let config = try parseConfiguration(
            "swiftdraw",
            "file.svg",
            "--format",
            "sfsymbol",
            "--ultralight-stroke-width",
            "50%"
        )
        #expect(config.ultralightStrokeScale?.multiplier == 0.5)
        #expect(config.blackStrokeScale == nil)
    }

    @Test
    func parseConfigurationBlackStrokeWidth() throws {
        let config = try parseConfiguration(
            "swiftdraw",
            "file.svg",
            "--format",
            "sfsymbol",
            "--black-stroke-width",
            "2"
        )
        #expect(config.blackStrokeScale?.multiplier == 2.0)
        #expect(config.ultralightStrokeScale == nil)
    }
}

private func parseConfiguration(_ args: String...) throws -> CommandLine.Configuration {
    try parseConfiguration(args)
}

private func parseConfiguration(_ args: [String]) throws -> CommandLine.Configuration {
    try CommandLine.parseConfiguration(from: args, baseDirectory: URL(directory: "/"))
}

private extension URL {

    init(directory: String) {
        self.init(fileURLWithPath: directory, isDirectory: true)
    }
}
