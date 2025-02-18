//
//  Parser.ImageTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/1/17.
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
import Foundation

final class ParserSVGImageTests: XCTestCase {

    func testShapes() throws {
        let svg = try DOM.SVG.parse(fileNamed: "shapes.svg", in: .test)

        XCTAssertEqual(svg.width, 500)
        XCTAssertEqual(svg.height, 700)
        XCTAssertEqual(svg.viewBox?.width, 500)
        XCTAssertEqual(svg.viewBox?.height, 700)
        XCTAssertEqual(svg.defs.clipPaths.count, 2)
        XCTAssertEqual(svg.defs.linearGradients.count, 1)
        XCTAssertEqual(svg.defs.radialGradients.count, 1)
        XCTAssertNotNil(svg.defs.elements["star"])
        XCTAssertEqual(svg.defs.elements.count, 2)

        var c = svg.childElements.enumerated().makeIterator()

        XCTAssertTrue(c.next()!.element is DOM.Ellipse)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Circle)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Line)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Polyline)
        XCTAssertTrue(c.next()!.element is DOM.Polyline)
        XCTAssertTrue(c.next()!.element is DOM.Polygon)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Circle)
        XCTAssertTrue(c.next()!.element is DOM.Switch)
        XCTAssertTrue(c.next()!.element is DOM.Rect)
        XCTAssertTrue(c.next()!.element is DOM.Text)
        XCTAssertTrue(c.next()!.element is DOM.Text)
        XCTAssertTrue(c.next()!.element is DOM.Line)
        XCTAssertTrue(c.next()!.element is DOM.Use)
        XCTAssertTrue(c.next()!.element is DOM.Use)
        XCTAssertTrue(c.next()!.element is DOM.Rect)
        XCTAssertNil(c.next())
    }

    func testStarry() throws {
        let svg = try DOM.SVG.parse(fileNamed: "starry.svg", in: .test)
        guard let g = svg.childElements.first as? DOM.Group,
              let g1 = g.childElements.first as? DOM.Group else {
            XCTFail("missing group")
            return
        }

        XCTAssertEqual(svg.width, 500)
        XCTAssertEqual(svg.height, 500)

        XCTAssertEqual(g1.childElements.count, 9323)

        var counter = [String: Int]()

        for e in g1.childElements {
            let key = String(describing: type(of: e))
            counter[key] = (counter[key] ?? 0) + 1
        }

        XCTAssertEqual(counter["Path"], 9314)
        XCTAssertEqual(counter["Polygon"], 9)
    }

    func testQuad() throws {
        let svg = try DOM.SVG.parse(fileNamed: "quad.svg", in: .test)
        XCTAssertEqual(svg.width, 1000)
        XCTAssertEqual(svg.height, 500)
    }

    func testCurves() throws {
        let svg = try DOM.SVG.parse(fileNamed: "curves.svg", in: .test)
        XCTAssertEqual(svg.width, 550)
        XCTAssertEqual(svg.height, 350)
    }

    func testNested() throws {
        let svg = try DOM.SVG.parse(fileNamed: "nested-svg.svg", in: .test)
        XCTAssertEqual(svg.width, 360)
        XCTAssertEqual(svg.height, 450)
    }
}
