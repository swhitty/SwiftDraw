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

import XCTest
@testable import SwiftDraw

final class CommandLineConfigurationTests: XCTestCase {

    func testParseFileURL() throws {
        let url = try CommandLine.parseFileURL(file: "file", within: URL(directory: "/test"))
        XCTAssertEqual(url, URL(fileURLWithPath: "/test/file"))

        let url1 = try CommandLine.parseFileURL(file: "file", within: URL(directory: "/test/subfolder"))
        XCTAssertEqual(url1, URL(fileURLWithPath: "/test/subfolder/file"))

        let url2 = try CommandLine.parseFileURL(file: "../file", within: URL(directory: "/test/subfolder"))
        XCTAssertEqual(url2, URL(fileURLWithPath: "/test/file"))
    }

    func testNewURLForFormat() throws {
        let svg = URL(fileURLWithPath: "/test/file.svg")
        XCTAssertEqual(svg.newURL(for: .jpeg, scale: .default), URL(fileURLWithPath: "/test/file.jpg"))
        XCTAssertEqual(svg.newURL(for: .png, scale: .default), URL(fileURLWithPath: "/test/file.png"))
        XCTAssertEqual(svg.newURL(for: .pdf, scale: .default), URL(fileURLWithPath: "/test/file.pdf"))

        let svgExtension = URL(fileURLWithPath: "/test/file")
        XCTAssertEqual(svgExtension.newURL(for: .jpeg, scale: .default), URL(fileURLWithPath: "/test/file.jpg"))
    }

    func testParseConfiguration() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "pdf")

        XCTAssertEqual(config.input, URL(fileURLWithPath: "/file.svg"))
        XCTAssertEqual(config.output, URL(fileURLWithPath: "/file.pdf"))
        XCTAssertEqual(config.scale, .default)
        XCTAssertEqual(config.format, .pdf)
        XCTAssertEqual(config.size, .default)
    }

    func testParseConfigurationSize() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "png", "--size", "400x300")

        XCTAssertEqual(config.input, URL(fileURLWithPath: "/file.svg"))
        XCTAssertEqual(config.output, URL(fileURLWithPath: "/file.png"))
        XCTAssertEqual(config.format, .png)
        XCTAssertEqual(config.size, .custom(width: 400, height: 300))
    }

    func testParseConfigurationScale2x() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "png", "--scale", "2x")

        XCTAssertEqual(config.input, URL(fileURLWithPath: "/file.svg"))
        XCTAssertEqual(config.output, URL(fileURLWithPath: "/file@2x.png"))
        XCTAssertEqual(config.scale, .retina)
        XCTAssertEqual(config.format, .png)
    }

    func testParseConfigurationThrows() {
        XCTAssertThrowsError(try parseConfiguration())
        XCTAssertThrowsError(try parseConfiguration("swiftdraw", "file.svg"))
        XCTAssertThrowsError(try parseConfiguration("swiftdraw", "file.svg", "--format", "unknown"))
    }

    func testParseInsets() throws {
        XCTAssertNil(
            try CommandLine.parseInsets(from: nil)
        )
        XCTAssertEqual(
            try CommandLine.parseInsets(from: "auto"),
            .init()
        )
        XCTAssertEqual(
            try CommandLine.parseInsets(from: "1,2,3,4"),
            .init(top: 1, left: 2, bottom: 3, right: 4)
        )
        XCTAssertEqual(
            try CommandLine.parseInsets(from: "0.995,auto,2.5,auto"),
            .init(top: 0.995, left: nil, bottom: 2.5, right: nil)
        )
        XCTAssertThrowsError(
            try CommandLine.parseInsets(from: "cab,1,2,2")
        )
        XCTAssertThrowsError(
            try CommandLine.parseInsets(from: "1,2")
        )
        XCTAssertThrowsError(
            try CommandLine.parseInsets(from: "")
        )
    }

    func testParseConfigurationInsets() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "sfsymbol", "--insets", "1,2,3.5,auto")

        XCTAssertEqual(config.insets.top, 1)
        XCTAssertEqual(config.insets.left, 2)
        XCTAssertEqual(config.insets.bottom, 3.5)
        XCTAssertEqual(config.insets.right, nil)
    }

    func testParseConfigurationAppKit() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "swift", "--api", "appkit")

        XCTAssertEqual(config.format, .swift)
        XCTAssertEqual(config.api, .appkit)
    }

    func testParseConfigurationUIKit() throws {
        let config = try parseConfiguration("swiftdraw", "file.svg", "--format", "swift", "--api", "uikit")

        XCTAssertEqual(config.format, .swift)
        XCTAssertEqual(config.api, .uikit)
    }

    func testAPIConversion() {
        XCTAssertEqual(CommandLine.makeTextAPI(for: nil), .swiftUI)
        XCTAssertEqual(CommandLine.makeTextAPI(for: .appkit), .appKit)
        XCTAssertEqual(CommandLine.makeTextAPI(for: .uikit), .uiKit)
    }
}

private func parseConfiguration(_ args: String...) throws -> CommandLine.Configuration {
    try CommandLine.parseConfiguration(from: args, baseDirectory: URL(directory: "/"))
}

private extension URL {

    init(directory: String) {
        self.init(fileURLWithPath: directory, isDirectory: true)
    }
}
