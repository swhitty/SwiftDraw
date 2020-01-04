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
    let config = try CommandLine.parseConfiguration(from: ["swiftdraw", "file.svg", "--format", "pdf"],
                                                    baseDirectory: URL(directory: "/"))

    XCTAssertEqual(config.input, URL(fileURLWithPath: "/file.svg"))
    XCTAssertEqual(config.output, URL(fileURLWithPath: "/file.pdf"))
    XCTAssertEqual(config.scale, .default)
    XCTAssertEqual(config.format, .pdf)
  }

  func testParseConfigurationScale2x() throws {
    let config = try CommandLine.parseConfiguration(from: ["swiftdraw", "file.svg", "--format", "png", "--scale", "2x"],
                                                    baseDirectory: URL(directory: "/"))

    XCTAssertEqual(config.input, URL(fileURLWithPath: "/file.svg"))
    XCTAssertEqual(config.output, URL(fileURLWithPath: "/file@2x.png"))
    XCTAssertEqual(config.scale, .retina)
    XCTAssertEqual(config.format, .png)
  }

  func testParseConfigurationThrows() {
    XCTAssertThrowsError(try CommandLine.parseConfiguration(from: [],
                                                            baseDirectory: URL(directory: "/")))
    XCTAssertThrowsError(try CommandLine.parseConfiguration(from: ["swiftdraw", "file.svg"],
                                                            baseDirectory: URL(directory: "/")))
    XCTAssertThrowsError(try CommandLine.parseConfiguration(from: ["swiftdraw", "file.svg", "--format", "unknown"],
                                                            baseDirectory: URL(directory: "/")))

  }
}

private extension URL {

  init(directory: String) {
    self.init(fileURLWithPath: directory, isDirectory: true)
  }
}
