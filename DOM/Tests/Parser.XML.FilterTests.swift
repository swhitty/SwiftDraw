//
//  Parser.XML.FilterTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/8/22.
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
@testable import SwiftDrawDOM

final class ParserXMLFilterTests: XCTestCase {

    func testParseFilters() throws {
        let child = XML.Element(name: "child")
        child.children = [XML.Element.makeMockFilter(), XML.Element.makeMockFilter()]

        let parent = XML.Element(name: "parent")
        parent.children = [XML.Element.makeMockFilter(), child]

        XCTAssertEqual(try XMLParser().parseFilters(child).count, 2)
        XCTAssertEqual(try XMLParser().parseFilters(parent).count, 3)
    }

    func testParseEffect() throws {
        let element = XML.Element.makeMockFilter(id: "blur")

        element.children = [
            .makeElement("feGaussianBlur", ["stdDeviation": "0.5"]),
            .makeElement("other")
        ]

        let filter = try XMLParser().parseFilter(element)
        XCTAssertEqual(filter.id, "blur")
        XCTAssertEqual(filter.effects, [.gaussianBlur(stdDeviation: 0.5)])
    }
}

private extension XML.Element {

    static func makeMockFilter(id: String = "mock") -> XML.Element {
        return XML.Element(name: "filter", attributes: ["id": id])
    }

    static func makeElement(_ name: String, _ attributes: [String: String] = [:]) -> XML.Element {
        return XML.Element(name: name, attributes: attributes)
    }
}
