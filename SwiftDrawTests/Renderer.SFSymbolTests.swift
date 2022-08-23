//
//  Renderer.SFSymbolTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 20/8/22.
//  Copyright 2022 Simon Whitty
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

final class RendererSFSymbolTests: XCTestCase {

    func testTemplateLoads() {
        XCTAssertNoThrow(try DOM.SVG.makeSFSymbolTemplate())
    }

    func testFillSymbol() throws {
        let url = try Bundle.test.url(forResource: "chart.svg")
        let symbols = try DOM.SVG.parse(
            SFSymbolRenderer.render(fileURL: url)
        ).group(id: "Symbols")

        XCTAssertEqual(
            try symbols.group(id: "Ultralight-S").childElements.count,
            1
        )
        XCTAssertEqual(
            try symbols.group(id: "Regular-S").childElements.count,
            1
        )
        XCTAssertEqual(
            try symbols.group(id: "Black-S").childElements.count,
            1
        )
    }

    #if canImport(CoreGraphics)
    func testStrokeSymbol() throws {
        let url = try Bundle.test.url(forResource: "key.svg")
        let symbols = try DOM.SVG.parse(
            SFSymbolRenderer.render(fileURL: url)
        ).group(id: "Symbols")

        XCTAssertEqual(
            try symbols.group(id: "Ultralight-S").childElements.count,
            1
        )
        XCTAssertEqual(
            try symbols.group(id: "Regular-S").childElements.count,
            1
        )
        XCTAssertEqual(
            try symbols.group(id: "Black-S").childElements.count,
            1
        )
    }

    func testStrokeText() throws {
        let source = try DOM.SVG.parse(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <circle cx="32" cy="32" r="28" fill="none" stroke="black" stroke-width="4" />
            <text font-size="35" x="14" y="45">W</text>
        </svg>
        """#)
        let symbols = try DOM.SVG.parse(
            SFSymbolRenderer.render(svg: source)
        ).group(id: "Symbols")

        XCTAssertEqual(
            try symbols.group(id: "Ultralight-S").childElements.count,
            2
        )
        XCTAssertEqual(
            try symbols.group(id: "Regular-S").childElements.count,
            2
        )
        XCTAssertEqual(
            try symbols.group(id: "Black-S").childElements.count,
            2
        )
    }
    #endif
}

private extension DOM.SVG {

    static func parse(_ text: String, filename: String = #file) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: text.data(using: .utf8)!)
        let parser = XMLParser(options: [], filename: filename)
        return try parser.parseSVG(element)
    }
}

private extension ContainerElement {

    func group(id: String) throws -> DOM.Group {
        for e in childElements {
            if e.id == id, let group = e as? DOM.Group {
                return group
            }
        }
        throw ContainerError.missingGroup
    }
}

enum ContainerError: Error {
    case missingGroup
}

private extension SFSymbolRenderer {

    static func render(fileURL: URL) throws -> String {
        let renderer = SFSymbolRenderer(options: [], precision: 3)
        return try renderer.render(fileURL: fileURL)
    }

    static func render(svg: DOM.SVG) throws -> String {
        let renderer = SFSymbolRenderer(options: [], precision: 3)
        return try renderer.render(svg: svg)
    }
}
