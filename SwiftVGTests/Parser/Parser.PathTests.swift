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
        AssertSegmentEquals("M 10 20", move(10, 20, .absolute))
        AssertSegmentEquals("m 10 20", move(10, 20, .relative))
        AssertSegmentEquals("M10,20", move(10, 20, .absolute))
        AssertSegmentEquals("M10;20", move(10, 20, .absolute))
        AssertSegmentEquals("M  10;  20    ", move(10, 20, .absolute))
    }
    
    func testLine() {
        AssertSegmentEquals("L 10 20 30 40", line(10, 20, 30, 40, .absolute))
        AssertSegmentEquals("l 10 20 30 40", line(10, 20, 30, 40, .relative))
        AssertSegmentEquals("L10,20,30,40", line(10, 20, 30, 40, .absolute))
        AssertSegmentEquals("L10;20;30;40", line(10, 20, 30, 40, .absolute))
        AssertSegmentEquals("  L 10;20   30; 40 ", line(10, 20, 30, 40, .absolute))
    }
    
    func testHorizontal() {
        AssertSegmentEquals("H 10", horizontal(10, .absolute))
        AssertSegmentEquals("h 10", horizontal(10, .relative))
        AssertSegmentEquals("H10", horizontal(10, .absolute))
        AssertSegmentEquals("H10;", horizontal(10, .absolute))
        AssertSegmentEquals("  H10 ", horizontal(10, .absolute))
    }
    
    func testVerical() {
        AssertSegmentEquals("V 10", vertical(10, .absolute))
        AssertSegmentEquals("v 10", vertical(10, .relative))
        AssertSegmentEquals("V10", vertical(10, .absolute))
        AssertSegmentEquals("V10;", vertical(10, .absolute))
        AssertSegmentEquals("  V10 ", vertical(10, .absolute))
    }
    
    func testCubic() {
        AssertSegmentEquals("C 10 20 30 40 50 60", cubic(10, 20, 30, 40, 50, 60, .absolute))
        AssertSegmentEquals("c 10 20 30 40 50 60", cubic(10, 20, 30, 40, 50, 60, .relative))
        AssertSegmentEquals("C10,20,30,40,50,60", cubic(10, 20, 30, 40, 50, 60, .absolute))
        AssertSegmentEquals("C10;20;30;40;50;60", cubic(10, 20, 30, 40, 50, 60, .absolute))
        AssertSegmentEquals("  C10;  20;  30 40; 50; 60", cubic(10, 20, 30, 40, 50, 60, .absolute))
    }
    
    func testCubicSmooth() {
        AssertSegmentEquals("S 10 20 50 60", cubicSmooth(10, 20, 50, 60, .absolute))
        AssertSegmentEquals("s 10 20 50 60", cubicSmooth(10, 20, 50, 60, .relative))
        AssertSegmentEquals("S10,20,50,60", cubicSmooth(10, 20, 50, 60, .absolute))
        AssertSegmentEquals("S10;20;50;60", cubicSmooth(10, 20, 50, 60, .absolute))
        AssertSegmentEquals("  S10;  20;  50; 60", cubicSmooth(10, 20, 50, 60, .absolute))
    }
    
    func testQuadratic() {
        AssertSegmentEquals("Q 10 20 50 60", quadratic(10, 20, 50, 60, .absolute))
        AssertSegmentEquals("q 10 20 50 60", quadratic(10, 20, 50, 60, .relative))
        AssertSegmentEquals("Q10,20,50,60", quadratic(10, 20, 50, 60, .absolute))
        AssertSegmentEquals("Q10;20;50;60", quadratic(10, 20, 50, 60, .absolute))
        AssertSegmentEquals("  Q10;  20;  50; 60", quadratic(10, 20, 50, 60, .absolute))
    }
    
    func testQuadraticSmooth() {
        AssertSegmentEquals("T 10 20", quadraticSmooth(10, 20, .absolute))
        AssertSegmentEquals("t 10 20", quadraticSmooth(10, 20, .relative))
        AssertSegmentEquals("T10,20", quadraticSmooth(10, 20, .absolute))
        AssertSegmentEquals("T10;20", quadraticSmooth(10, 20, .absolute))
        AssertSegmentEquals("  T10;  20;", quadraticSmooth(10, 20, .absolute))
    }
    
    func testArc() {
        AssertSegmentEquals("A 10 20 30 40 50 1 0", arc(10, 20, 30, 40, 50, true, false, .absolute))
        AssertSegmentEquals("a 10 20 30 40 50 1 0", arc(10, 20, 30, 40, 50, true, false, .relative))
        AssertSegmentEquals("A10,20,30,40,50,1,0", arc(10, 20, 30, 40, 50, true, false, .absolute))
        AssertSegmentEquals("A10;20;30;40;50;1;0", arc(10, 20, 30, 40, 50, true, false, .absolute))
        AssertSegmentEquals("  A10; 20;  30;40 50; 1  0 ", arc(10, 20, 30, 40, 50, true, false, .absolute))
    }
    
    func testClose() {
        AssertSegmentEquals("Z", .close)
        AssertSegmentEquals("z", .close)
        AssertSegmentEquals("  z ", .close)
    }
    
    func testPath() {
        let node = ["d": "M 10 10 h 10 v 10 h -10 v -10"]
        let parser = XMLParser()
        
        let path = try! parser.parsePath2(node)
        
        XCTAssertEqual(path.segments.count, 5)
        
        XCTAssertEqual(path.segments[0], .move(x: 10, y: 10, space: .absolute))
        XCTAssertEqual(path.segments[1], .horizontal(x: 10, space: .relative))
        XCTAssertEqual(path.segments[2], .vertical(y: 10, space: .relative))
        XCTAssertEqual(path.segments[3], .horizontal(x: -10, space: .relative))
        XCTAssertEqual(path.segments[4], .vertical(y: -10, space: .relative))
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

private func horizontal(_ x: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .horizontal(x: x, space: space)
}

private func vertical(_ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .vertical(y: y, space: space)
}

private func cubic(_ x: Coordinate, _ y: Coordinate,
                  _ x1: Coordinate, _ y1: Coordinate,
                  _ x2: Coordinate, _ y2: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .cubic(x: x, y: y, x1: x1, y1: y1, x2: x2, y2: y2, space: space)
}

private func cubicSmooth(_ x: Coordinate, _ y: Coordinate,
                         _ x2: Coordinate, _ y2: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .cubicSmooth(x: x, y: y, x2: x2, y2: y2, space: space)
}

private func quadratic(_ x: Coordinate, _ y: Coordinate,
                         _ x1: Coordinate, _ y1: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .quadratic(x: x, y: y, x1: x1, y1: y1, space: space)
}

private func quadraticSmooth(_ x: Coordinate, _ y: Coordinate, _ space: CoordinateSpace) -> Segment {
    return .quadraticSmooth(x: x, y: y, space: space)
}

private func arc(_ x: Coordinate, _ y: Coordinate,
                   _ rx: Coordinate, _ ry: Coordinate,
                   _ rotate: Coordinate, _ large: Bool,
                   _ sweep: Bool, _ space: CoordinateSpace) -> Segment {
    return .arc(x: x, y: y,
                rx: rx, ry: ry,
                rotate: rotate, large: large,
                sweep: sweep, space: space)
}



extension DOM.Path2.Segment: Equatable {
    public static func ==(lhs: DOM.Path2.Segment, rhs: DOM.Path2.Segment) -> Bool {
        let toString: (Any) -> String = { var text = ""; dump($0, to: &text); return text }
        return toString(lhs) == toString(rhs)
    }
}
