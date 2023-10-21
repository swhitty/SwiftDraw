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
        XCTAssertNoThrow(try SFSymbolTemplate.make())
    }

    func testFillSymbol() throws {
        let url = try Bundle.test.url(forResource: "chart.svg")
        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(fileURL: url)
        )

        XCTAssertFalse(
            template.ultralight.contents.paths.isEmpty
        )
        XCTAssertFalse(
            template.regular.contents.paths.isEmpty
        )
        XCTAssertFalse(
            template.black.contents.paths.isEmpty
        )
    }
    
    func testWidthGreaterThanHeightSymbol() throws {
        // This svg has a width of 24, but a height of 4. When scaling in SFSymbolRenderer makeTransformation
        // the height was being used to create scale causing the width to be 440 instead of 108.
        let url = try Bundle.test.url(forResource: "dash.svg")
        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(fileURL: url)
        )

        XCTAssertTrue(
            template.regular.bounds.size.width == 108.0
        )
        XCTAssertTrue(
            template.regular.bounds.size.height == 70.0
        )

    }

    func testTransparentLayers_Are_Removed() throws {
        let source = try DOM.SVG.parse(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <rect width="100" height="100" fill="currentColor" />
            <rect width="100" height="100" fill="transparent" />
            <rect width="100" height="100" fill="currentColor" opacity="0" />
        </svg>
        """#)

        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(svg: source)
        )

        XCTAssertEqual(
            template.ultralight.contents.paths.count,
            1
        )
        XCTAssertEqual(
            template.regular.contents.paths.count,
            1
        )
        XCTAssertEqual(
            template.black.contents.paths.count,
            1
        )
    }

    func testTransparentSFSymboleLayers_AreNot_Removed() throws {
        let source = try DOM.SVG.parse(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <rect width="100" height="100" fill="currentColor" />
            <rect width="100" height="100" fill="transparent" class="multicolor-0:custom" />
            <rect width="100" height="100" fill="currentColor" opacity="0" class="SFSymbolsPreview" />
        </svg>
        """#)

        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(svg: source)
        )

        XCTAssertEqual(
            template.ultralight.contents.paths.count,
            3
        )
        XCTAssertEqual(
            template.regular.contents.paths.count,
            3
        )
        XCTAssertEqual(
            template.black.contents.paths.count,
            3
        )
    }

    #if canImport(CoreGraphics)
    func testStrokeSymbol() throws {
        let url = try Bundle.test.url(forResource: "key.svg")
        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(fileURL: url)
        )

        XCTAssertFalse(
            template.ultralight.contents.paths.isEmpty
        )
        XCTAssertFalse(
            template.regular.contents.paths.isEmpty
        )
        XCTAssertFalse(
            template.black.contents.paths.isEmpty
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

        let template = try SFSymbolTemplate.parse(
            SFSymbolRenderer.render(svg: source)
        )

        XCTAssertEqual(
            template.ultralight.contents.paths.count,
            2
        )
        XCTAssertEqual(
            template.regular.contents.paths.count,
            2
        )
        XCTAssertEqual(
            template.black.contents.paths.count,
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

private extension SFSymbolRenderer {

    static func render(fileURL: URL) throws -> String {
        let renderer = SFSymbolRenderer(options: [], insets: .init(),
                                        insetsUltralight: .init(),
                                        insetsBlack: .init(),
                                        precision: 3)
        return try renderer.render(regular: fileURL, ultralight: nil, black: nil)
    }

    static func render(svg: DOM.SVG) throws -> String {
        let renderer = SFSymbolRenderer(options: [], insets: .init(),
                                        insetsUltralight: .init(),
                                        insetsBlack: .init(),
                                        precision: 3)
        return try renderer.render(default: svg, ultralight: nil, black: nil)
    }
}
