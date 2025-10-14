//
//  Parser.XML.PathTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 8/3/17.
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
import SwiftDrawDOM
import Testing

@testable import SwiftDrawDOM

private typealias Coordinate = DOM.Coordinate
private typealias Segment = DOM.Path.Segment
private typealias CoordinateSpace = DOM.Path.Segment.CoordinateSpace

@Suite("Parser XML Path Tests")
struct ParserXMLPathTests {

    @Test
    func scanBool() throws {
        let scanner = XMLParser.PathScanner(string: "true FALSE 0 1")

        #expect(try scanner.scanBool() == true)
        #expect(try scanner.scanBool() == false)
        #expect(try scanner.scanBool() == false)
        #expect(try scanner.scanBool() == true)
        #expect(throws: (any Error).self) { _ = try scanner.scanBool() }
    }

    @Test
    func scanCoordinate() throws {
        let scanner = XMLParser.PathScanner(string: "10 20.0")

        #expect(try scanner.scanCoordinate() == 10.0)
        #expect(try scanner.scanCoordinate() == 20.0)
        #expect(throws: (any Error).self) { _ = try scanner.scanCoordinate() }
    }

    @Test
    func equality() {
        #expect(Segment.move(x: 10, y: 20, space: .relative) == move(10, 20, .relative))

        #expect(Segment.move(x: 20, y: 20, space: .absolute) != move(10, 20, .absolute))

        #expect(Segment.move(x: 10, y: 20, space: .relative) != move(10, 20, .absolute))
    }

    @Test
    func empty() throws {
        let parser = SwiftDrawDOM.XMLParser()
        #expect(try parser.parsePathSegments("") == [])
        #expect(try parser.parsePathSegments("       ") == [])
    }

    @Test
    func moveSegments() {
        #expect(parseSegment("M 10 20") == move(10, 20, .absolute))
        #expect(parseSegment("m 10 20") == move(10, 20, .relative))
        #expect(parseSegment("M10,20") == move(10, 20, .absolute))
        #expect(parseSegment("M10;20") == move(10, 20, .absolute))
        #expect(parseSegment("M  10;  20    ") == move(10, 20, .absolute))
        #expect(parseSegment("M10-20") == move(10, -20, .absolute))

        #expect(parseSegments("M10-20 5 1") == [move(10, -20, .absolute),
                                                line(5, 1, .absolute)])

        #expect(parseSegments("m10-20 5 1") == [move(10, -20, .relative),
                                                line(5, 1, .relative)])
    }

    @Test
    func lineSegments() {
        #expect(parseSegment("L 10 20") == line(10, 20, .absolute))
        #expect(parseSegment("l 10 20") == line(10, 20, .relative))
        #expect(parseSegment("L10,20") == line(10, 20, .absolute))
        #expect(parseSegment("L10;20") == line(10, 20, .absolute))
        #expect(parseSegment("  L 10;20  ") == line(10, 20, .absolute))
        #expect(parseSegment("L10-20  ") == line(10, -20, .absolute))

        #expect(parseSegments("L10-20 5 1") == [line(10, -20, .absolute),
                                                line(5, 1, .absolute)])
    }

    @Test
    func horizontalSegments() {
        #expect(parseSegment("H 10") == horizontal(10, .absolute))
        #expect(parseSegment("h 10") == horizontal(10, .relative))
        #expect(parseSegment("H10") == horizontal(10, .absolute))
        #expect(parseSegment("H10;") == horizontal(10, .absolute))
        #expect(parseSegment("  H10 ") == horizontal(10, .absolute))

        #expect(parseSegments("h10 5") == [horizontal(10, .relative),
                                           horizontal(5, .relative)])
    }

    @Test
    func vericalSegments() {
        #expect(parseSegment("V 10") == vertical(10, .absolute))
        #expect(parseSegment("v 10") == vertical(10, .relative))
        #expect(parseSegment("V10") == vertical(10, .absolute))
        #expect(parseSegment("V10;") == vertical(10, .absolute))
        #expect(parseSegment("  V10 ") == vertical(10, .absolute))
    }

    @Test
    func cubicSmoothSegments() {
        #expect(parseSegment("S 10 20 50 60") == cubicSmooth(10, 20, 50, 60, .absolute))
        #expect(parseSegment("s 10 20 50 60") == cubicSmooth(10, 20, 50, 60, .relative))
        #expect(parseSegment("S10,20,50,60") == cubicSmooth(10, 20, 50, 60, .absolute))
        #expect(parseSegment("S10;20;50;60") == cubicSmooth(10, 20, 50, 60, .absolute))
        #expect(parseSegment("  S10;  20;  50; 60") == cubicSmooth(10, 20, 50, 60, .absolute))
    }

    @Test
    func quadraticSegments() {
        #expect(parseSegment("Q 10 20 50 60") == quadratic(10, 20, 50, 60, .absolute))
        #expect(parseSegment("q 10 20 50 60") == quadratic(10, 20, 50, 60, .relative))
        #expect(parseSegment("Q10,20,50,60") == quadratic(10, 20, 50, 60, .absolute))
        #expect(parseSegment("Q10;20;50;60") == quadratic(10, 20, 50, 60, .absolute))
        #expect(parseSegment("  Q10;  20;  50; 60") == quadratic(10, 20, 50, 60, .absolute))
    }

    @Test
    func quadraticSmoothSegments() {
        #expect(parseSegment("T 10 20") == quadraticSmooth(10, 20, .absolute))
        #expect(parseSegment("t 10 20") == quadraticSmooth(10, 20, .relative))
        #expect(parseSegment("T10,20") == quadraticSmooth(10, 20, .absolute))
        #expect(parseSegment("T10;20") == quadraticSmooth(10, 20, .absolute))
        #expect(parseSegment("  T10;  20;") == quadraticSmooth(10, 20, .absolute))
    }

    @Test
    func arcSegments() {
        #expect(parseSegment("  A10; 20;  30; 1  0;40 50") == arc(10, 20, 30, true, false, 40, 50, .absolute))
    }

    @Test
    func closeSegments() {
        #expect(parseSegment("Z") == .close)
        #expect(parseSegment("z") == .close)
        #expect(parseSegment("  z ") == .close)
    }

    @Test
    func path() throws {
        let node = ["d": "M 10 10 h 10 v 10 h -10 v -10"]
        let parser = DOMXMLParser()

        let path = try parser.parsePath(node)

        #expect(path.segments.count == 5)

        #expect(path.segments[0] == .move(x: 10, y: 10, space: .absolute))
        #expect(path.segments[1] == .horizontal(x: 10, space: .relative))
        #expect(path.segments[2] == .vertical(y: 10, space: .relative))
        #expect(path.segments[3] == .horizontal(x: -10, space: .relative))
        #expect(path.segments[4] == .vertical(y: -10, space: .relative))
    }

    @Test
    func pathLineBreak() throws {
        let node = ["d": "M230 520\n  \t\t A 45 45, 0, 1, 0, 275 565 \n \t\t L 275 520 Z"]
        let parser = DOMXMLParser()

        let path = try? parser.parsePath(node)

        #expect(path?.segments.count == 4)
    }

    @Test
    func pathLong() throws {

        let node = ["d": "m10,2h-30v-40zm50,60"]
        let parser = DOMXMLParser()

        let path = try parser.parsePath(node)

        #expect(path.segments.count == 5)

        #expect(path.segments[0] == .move(x: 10, y: 2.0, space: .relative))
        #expect(path.segments[1] == .horizontal(x: -30, space: .relative))
        #expect(path.segments[2] == .vertical(y: -40, space: .relative))
        #expect(path.segments[3] == .close)
        #expect(path.segments[4] == .move(x: 50, y: 60, space: .relative))
    }
}

private func parseSegment(_ text: String) -> Segment? {
    let parsed = try? XMLParser().parsePathSegments(text)
    return parsed?[0]
}

private func parseSegments(_ text: String) -> [Segment] {
    let parsed = try? XMLParser().parsePathSegments(text)
    return parsed ?? []
}

// helpers to create Segments without labels
// splatting of tuple is no longer supported
private func move(_ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .move(x: x, y: y, space: space)
}

private func line(_ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .line(x: x, y: y, space: space)
}

private func horizontal(_ x: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .horizontal(x: x, space: space)
}

private func vertical(_ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .vertical(y: y, space: space)
}

private func cubic(_ x1: Coordinate, _ y1: Coordinate,
                   _ x2: Coordinate, _ y2: Coordinate,
                   _ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .cubic(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y, space: space)
}

private func cubicSmooth(_ x2: Coordinate, _ y2: Coordinate,
                         _ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .cubicSmooth(x2: x2, y2: y2, x: x, y: y, space: space)
}

private func quadratic(_ x1: Coordinate, _ y1: Coordinate,
                       _ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .quadratic(x1: x1, y1: y1, x: x, y: y, space: space)
}

private func quadraticSmooth(_ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .quadraticSmooth(x: x, y: y, space: space)
}

private func arc(_ rx: Coordinate, _ ry: Coordinate, _ rotate: Coordinate,
                 _ large: Bool, _ sweep: Bool,
                 _ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .arc(rx: rx, ry: ry, rotate: rotate,
                large: large, sweep: sweep,
                x: x, y: y, space: space)
}
