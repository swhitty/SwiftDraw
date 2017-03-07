//
//  Parser.PathTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 8/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

private typealias Coordinate = DOM.Coordinate
private typealias Segment = DOM.Path2.Segment
private typealias CoordinateSpace = DOM.Path2.Segment.CoordinateSpace

class ParserPathTests: XCTestCase {
    
    func testEquality() {
        XCTAssertEqual(Segment.move(x: 10, y: 20, space: .relative),
                       move(10, 20, .relative))

        XCTAssertNotEqual(Segment.move(x: 20, y: 20, space: .absolute),
                          move(10, 20, .absolute))
        
        XCTAssertNotEqual(Segment.move(x: 10, y: 20, space: .relative),
                          move(10, 20, .absolute))
    }
    
    func testMove() {
        AssertSegmentEquals("M 10 20",move(10, 20, .absolute))
        AssertSegmentEquals("M10,20",move(10, 20, .absolute))
        AssertSegmentEquals("M10;20",move(10, 20, .absolute))
        AssertSegmentEquals("M  10;  20    ",move(10, 20, .absolute))
    }
    
    func testLine() {
        AssertSegmentEquals("L 10 20 30 40",line(10, 20, 30, 40, .absolute))
        AssertSegmentEquals("L10,20,30,40",line(10, 20, 30, 40, .absolute))
        AssertSegmentEquals("L10;20;30;40",line(10, 20, 30, 40, .absolute))
        AssertSegmentEquals("  L 10;20   30; 40 ",line(10, 20, 30, 40, .absolute))
    }
    
}

private func AssertSegmentEquals(_ text: String, _ expected: DOM.Path2.Segment, file: StaticString = #file, line: UInt = #line) {
    var scanner = Scanner(text: text)
    let parsed = try? XMLParser().parsePathSegment(&scanner)
    XCTAssertEqual(parsed, expected, file: file, line: line)
}


// helpers to create Segments without labels
// splatting pf tuple is no longer supported
private func move(_ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .move(x: x, y: y, space: space)
}

private func line(_ x1: Coordinate, _ y1: Coordinate,
                  _ x2: Coordinate, _ y2: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .line(x1: x1, y1: y1, x2: x2, y2: y2, space: space)
}


    

extension DOM.Path2.Segment: Equatable {
    public static func ==(lhs: DOM.Path2.Segment, rhs: DOM.Path2.Segment) -> Bool {
        let toString: (Any) -> String = { var text = ""; dump($0, to: &text); return text }
        return toString(lhs) == toString(rhs)
    }
}
