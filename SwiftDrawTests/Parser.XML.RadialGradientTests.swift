//
//  Parser.XML.RadialGradientTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/8/22.
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


import Foundation

import XCTest
@testable import SwiftDraw

final class ParserXMLRadialGradientTests: XCTestCase {

    func testParseGradients() throws {
        let child = XML.Element(name: "child")
        child.children = [XML.Element.makeMockGradient(), XML.Element.makeMockGradient()]

        let parent = XML.Element(name: "parent")
        parent.children = [XML.Element.makeMockGradient(), child]

        XCTAssertEqual(try XMLParser().parseRadialGradients(child).count, 2)
        XCTAssertEqual(try XMLParser().parseRadialGradients(parent).count, 3)
    }

    func testParseCoordinates() throws {
        let element = XML.Element.makeMockGradient()
        element.attributes["r"] = "0.1"
        element.attributes["cx"] = "0.2"
        element.attributes["cy"] = "0.3"
        element.attributes["fr"] = "0.4"
        element.attributes["fx"] = "0.5"
        element.attributes["fy"] = "0.6"

        let gradient = try XMLParser().parseRadialGradient(element)
        XCTAssertEqual(gradient.r, 0.1)
        XCTAssertEqual(gradient.cx, 0.2)
        XCTAssertEqual(gradient.cy, 0.3)
        XCTAssertEqual(gradient.fr, 0.4)
        XCTAssertEqual(gradient.fx, 0.5)
        XCTAssertEqual(gradient.fy, 0.6)
    }

    func testParseFile() throws {

        let dom = try DOM.SVG.parse(fileNamed: "radialGradient.svg")

        XCTAssertEqual(dom.defs.radialGradients.count, 5)
        XCTAssertNotNil(dom.defs.radialGradients.first(where: { $0.id == "snow" }))
        XCTAssertNotNil(dom.defs.radialGradients.first(where: { $0.id == "blue" }))
        XCTAssertNotNil(dom.defs.radialGradients.first(where: { $0.id == "purple" }))
        XCTAssertNotNil(dom.defs.radialGradients.first(where: { $0.id == "salmon" }))
        XCTAssertNotNil(dom.defs.radialGradients.first(where: { $0.id == "green" }))

        XCTAssertGreaterThan(dom.childElements.count, 2)
        XCTAssertEqual(dom.childElements[0].attributes.fill, .url(URL(string: "#snow")!))
        XCTAssertEqual(dom.childElements[1].attributes.fill, .url(URL(string: "#blue")!))
    }
}

private extension XML.Element {

    static func makeMockGradient() -> XML.Element {
        return XML.Element(name: "radialGradient", attributes: ["id": "mock"])
    }
}
