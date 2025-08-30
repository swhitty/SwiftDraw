//
//  Parser.XML.ElementTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
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

@testable import SwiftDrawDOM
import Testing

struct XMLParserElementTests {

    @Test
    func line() {
        let node = ["x1": "0",
                    "y1": "10",
                    "x2": "50",
                    "y2": "60"]

        let parsed = try? XMLParser().parseLine(node)
        #expect(DOM.Line(x1: 0, y1: 10, x2: 50, y2: 60) == parsed)
    }

    @Test
    func circle() {
        let node = ["cx": "0",
                    "cy": "10",
                    "r": "20"]

        let parsed = try? XMLParser().parseCircle(node)
        #expect(DOM.Circle(cx: 0, cy: 10, r: 20) == parsed)
    }

    @Test
    func ellipse() {
        let node = ["cx": "0",
                    "cy": "10",
                    "rx": "20",
                    "ry": "30"]

        let parsed = try? XMLParser().parseEllipse(node)
        #expect(DOM.Ellipse(cx: 0, cy: 10, rx: 20, ry: 30) == parsed)
    }

    @Test
    func rect() throws {
        var node = ["x": "0",
                    "y": "10",
                    "width": "20",
                    "height": "30"]

        let rect = DOM.Rect(x: 0, y: 10, width: 20, height: 30)
        #expect(try XMLParser().parseRect(node) == rect)

        node["rx"] = "3"
        node["ry"] = "2"
        rect.rx = 3
        rect.ry = 2
        #expect(try XMLParser().parseRect(node) == rect)
    }

    @Test
    func polyline() {
        let node = ["points": "0,1 2 3; 4;5;6;7;8 9"]

        let parsed = try? XMLParser().parsePolyline(node)
        #expect(DOM.Polyline(0, 1, 2, 3, 4, 5, 6, 7, 8, 9) == parsed)
    }

    @Test
    func polygon() {
        let att = ["points": "0, 1,2,3;4;5;6;7;8 9"]
        let parsed =  try? XMLParser().parsePolygon(att)
        #expect(DOM.Polygon(0, 1, 2, 3, 4, 5, 6, 7, 8, 9) == parsed)
    }

    @Test
    func polygonFillRule() throws {
        let att = ["points": "0,1,2,3;4;5;6;7;8 9"]
        #expect((try XMLParser().parsePolygon(att)).attributes.fillRule == nil)

        let node = XML.Element(name: "polygon")
        node.attributes["points"] = "0,1,2,3"

        node.attributes["fill-rule"] = "nonzero"
        #expect(try XMLParser().parseGraphicsElement(node)!.attributes.fillRule == .nonzero)

        node.attributes["fill-rule"] = "evenodd"
        #expect(try XMLParser().parseGraphicsElement(node)!.attributes.fillRule == .evenodd)

        node.attributes["fill-rule"] = "asdf"
        #expect(throws: (any Error).self) {
            _ = try XMLParser().parseGraphicsElement(node)!.attributes.fillRule
        }
    }

    @Test
    func elementParserSkipsErrors() {
        let error = XMLParser().parseError(for: XMLParser.Error.invalid,
                                           parsing: XML.Element(name: "polygon"),
                                           with: [.skipInvalidElements])

        #expect(error == nil)
    }

    @Test
    func elementParserErrorsPreserveLineNumbers() {
        let invalidElement = XMLParser.Error.invalidElement(name: "polygon",
                                                            error: XMLParser.Error.invalid,
                                                            line: 100,
                                                            column: 50)

        let parseError = XMLParser().parseError(for: invalidElement,
                                                parsing: XML.Element(name: "polygon"),
                                                with: [])

        switch parseError! {
        case let .invalidElement(_, _, line, column):
            #expect(line == 100)
            #expect(column == 50)
        default:
            Issue.record("not forwarderd")
            #expect(Bool(false))
        }
    }

    @Test
    func elementParserErrorsPreserveLineNumbersFromElement() {
        let element = XML.Element(name: "polygon")
        element.parsedLocation = (line: 100, column: 50)

        let parseError = XMLParser().parseError(for: XMLParser.Error.invalid,
                                                parsing: element,
                                                with: [])

        switch parseError! {
        case let .invalidElement(_, _, line, column):
            #expect(line == 100)
            #expect(column == 50)
        default:
            Issue.record("not forwarderd")
            #expect(Bool(false))
        }
    }
}
