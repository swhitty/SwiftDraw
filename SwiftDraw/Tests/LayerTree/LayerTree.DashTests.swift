//
//  LayerTree.DashTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/12/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw
import Foundation

final class LayerTreeDashTests: XCTestCase {

    private func dashes(_ svgBody: String, attributes: String = "") throws -> [(phase: Float, lengths: [Float])] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" \(attributes)>\(svgBody)</svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default).compactMap {
            if case let .setLineDash(phase: p, lengths: l) = $0 { return (p, l) }
            return nil
        }
    }

    func testBasicDashAndOffset() throws {
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 2" stroke-dashoffset="1"/>"#)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].lengths, [4, 2])
        XCTAssertEqual(d[0].phase, 1)
    }

    func testOddListRepeats() throws {
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="5,3,2"/>"#)
        XCTAssertEqual(d[0].lengths, [5, 3, 2, 5, 3, 2])
    }

    func testNegativeInvalidatesAttribute() throws {
        XCTAssertTrue(try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 -2"/>"#).isEmpty)
    }

    func testGarbageDoesNotDropDocument() throws {
        XCTAssertTrue(try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="abc"/>"#).isEmpty)
    }

    func testAllZeroIsSolid() throws {
        XCTAssertTrue(try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="0 0"/>"#).isEmpty)
    }

    func testNoneOverridesInherited() throws {
        let d = try dashes(#"<g stroke-dasharray="4 2"><path d="M0 0 L5 5" stroke="black" stroke-dasharray="none"/><path d="M0 0 L9 9" stroke="black"/></g>"#)
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].lengths, [4, 2])
    }

    func testStyleAttributeAndGroupInheritance() throws {
        let d = try dashes(#"<g style="stroke-dasharray: 6 3; stroke-dashoffset: 2"><path d="M0 0 L50 50" stroke="black"/></g>"#)
        XCTAssertEqual(d[0].lengths, [6, 3])
        XCTAssertEqual(d[0].phase, 2)
    }

    func testPercentageRelativeToViewportDiagonal() throws {
        // width=height=100 => normalized diagonal = 100
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="10% 5%"/>"#)
        XCTAssertEqual(d[0].lengths[0], 10, accuracy: 0.001)
        XCTAssertEqual(d[0].lengths[1], 5, accuracy: 0.001)
    }

    func testSolidStrokeEmitsNoDashCommand() throws {
        XCTAssertTrue(try dashes(#"<path d="M0 0 L50 50" stroke="black"/>"#).isEmpty)
    }
}
