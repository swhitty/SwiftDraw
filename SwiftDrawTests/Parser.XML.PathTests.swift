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

import XCTest
@testable import SwiftDraw

private typealias Coordinate = DOM.Coordinate
private typealias Segment = DOM.Path.Segment
private typealias CoordinateSpace = DOM.Path.Segment.CoordinateSpace

final class ParserXMLPathTests: XCTestCase {
  
  func testScanBool() {
    let scanner = XMLParser.PathScanner(string: "true FALSE 0 1")
    
    XCTAssertTrue(try scanner.scanBool())
    XCTAssertFalse(try scanner.scanBool())
    XCTAssertFalse(try scanner.scanBool())
    XCTAssertTrue(try scanner.scanBool())
    XCTAssertThrowsError(try scanner.scanBool())
  }
  
  func testScanCoordinate() {
    let scanner = XMLParser.PathScanner(string: "10 20.0")
    
    XCTAssertEqual(try scanner.scanCoordinate(), 10.0)
    XCTAssertEqual(try scanner.scanCoordinate(), 20.0)
    XCTAssertThrowsError(try scanner.scanCoordinate())
  }
  
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
    AssertSegmentEquals("M10-20", move(10, -20, .absolute))
    
    AssertSegmentsEquals("M10-20 5 1", [move(10, -20, .absolute),
                                        line(5, 1, .absolute)])

    AssertSegmentsEquals("m10-20 5 1", [move(10, -20, .relative),
                                        line(5, 1, .relative)])
  }
  
  func testLine() {
    AssertSegmentEquals("L 10 20", line(10, 20, .absolute))
    AssertSegmentEquals("l 10 20", line(10, 20, .relative))
    AssertSegmentEquals("L10,20", line(10, 20, .absolute))
    AssertSegmentEquals("L10;20", line(10, 20, .absolute))
    AssertSegmentEquals("  L 10;20  ", line(10, 20, .absolute))
    AssertSegmentEquals("L10-20  ", line(10, -20, .absolute))
    
    AssertSegmentsEquals("L10-20 5 1", [line(10, -20, .absolute),
                                        line(5, 1, .absolute)])
  }
  
  func testHorizontal() {
    AssertSegmentEquals("H 10", horizontal(10, .absolute))
    AssertSegmentEquals("h 10", horizontal(10, .relative))
    AssertSegmentEquals("H10", horizontal(10, .absolute))
    AssertSegmentEquals("H10;", horizontal(10, .absolute))
    AssertSegmentEquals("  H10 ", horizontal(10, .absolute))
    
    AssertSegmentsEquals("h10 5", [horizontal(10, .relative),
                                   horizontal(5, .relative)])
  }
  
  func testVerical() {
    AssertSegmentEquals("V 10", vertical(10, .absolute))
    AssertSegmentEquals("v 10", vertical(10, .relative))
    AssertSegmentEquals("V10", vertical(10, .absolute))
    AssertSegmentEquals("V10;", vertical(10, .absolute))
    AssertSegmentEquals("  V10 ", vertical(10, .absolute))
  }
  
//  func testCubic() {
//    AssertSegmentEquals("C 10 20 30 40 50 60", cubic(10, 20, 30, 40, 50, 60, .absolute))
//    AssertSegmentEquals("c 10 20 30 40 50 60", cubic(10, 20, 30, 40, 50, 60, .relative))
//    AssertSegmentEquals("C10,20,30,40,50,60", cubic(10, 20, 30, 40, 50, 60, .absolute))
//    AssertSegmentEquals("C10;20;30;40;50;60", cubic(10, 20, 30, 40, 50, 60, .absolute))
//    AssertSegmentEquals("  C10;  20;  30 40; 50; 60", cubic(10, 20, 30, 40, 50, 60, .absolute))
//  }
  
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
      //
//    AssertSegmentEquals("A 10 20 30 1 0 40 50", arc(10, 20, 30, true, false, 40, 50, .absolute))
//    AssertSegmentEquals("a 10 20 30 1 0 40 50", arc(10, 20, 30, true, false, 40, 50, .relative))
//    AssertSegmentEquals("A10,20,30,1,0,40,50", arc(10, 20, 30, true, false, 40, 50, .absolute))
//    AssertSegmentEquals("A10;20;30;1;0;40;50", arc(10, 20, 30, true, false, 40, 50, .absolute))
    AssertSegmentEquals("  A10; 20;  30; 1  0;40 50", arc(10, 20, 30, true, false, 40, 50, .absolute))
  }
  
  func testClose() {
    AssertSegmentEquals("Z", .close)
    AssertSegmentEquals("z", .close)
    AssertSegmentEquals("  z ", .close)
  }
  
  func testPath() {
    let node = ["d": "M 10 10 h 10 v 10 h -10 v -10"]
    let parser = XMLParser()
    
    let path = try! parser.parsePath(node)
    
    XCTAssertEqual(path.segments.count, 5)
    
    XCTAssertEqual(path.segments[0], .move(x: 10, y: 10, space: .absolute))
    XCTAssertEqual(path.segments[1], .horizontal(x: 10, space: .relative))
    XCTAssertEqual(path.segments[2], .vertical(y: 10, space: .relative))
    XCTAssertEqual(path.segments[3], .horizontal(x: -10, space: .relative))
    XCTAssertEqual(path.segments[4], .vertical(y: -10, space: .relative))
  }
  
  func testPathLineBreak() {
    let node = ["d": "M230 520\n  \t\t A 45 45, 0, 1, 0, 275 565 \n \t\t L 275 520 Z"]
    let parser = XMLParser()
    
    let path = try? parser.parsePath(node)
    
    XCTAssertEqual(path?.segments.count, 4)
  }
  
  func testPathLong() throws {
    
    let node = ["d": "m10,2h-30v-40zm50,60"]
    let parser = XMLParser()
    
    let path = try! parser.parsePath(node)
    
    XCTAssertEqual(path.segments.count, 5)
    
    XCTAssertEqual(path.segments[0], .move(x: 10, y: 2.0, space: .relative))
    XCTAssertEqual(path.segments[1], .horizontal(x: -30, space: .relative))
    XCTAssertEqual(path.segments[2], .vertical(y: -40, space: .relative))
    XCTAssertEqual(path.segments[3], .close)
    XCTAssertEqual(path.segments[4], .move(x: 50, y: 60, space: .relative))
  }
}

private func AssertSegmentEquals(_ text: String, _ expected: Segment, file: StaticString = #file, line: UInt = #line) {
  let parsed = try? XMLParser().parsePathSegments(text)
  XCTAssertEqual(parsed?.count, 1)
  XCTAssertEqual(parsed![0], expected, file: file, line: line)
}

private func AssertSegmentsEquals(_ text: String, _ expected: [Segment], file: StaticString = #file, line: UInt = #line) {
  guard let parsed = try? XMLParser().parsePathSegments(text) else {
    XCTFail("could not parse segments", file: file, line: line)
    return
  }
  XCTAssertEqual(parsed, expected, file: file, line: line)
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



extension DOM.Path.Segment: Swift.Equatable {
  public static func ==(lhs: DOM.Path.Segment, rhs: DOM.Path.Segment) -> Bool {
    let toString: (Any) -> String = { var text = ""; dump($0, to: &text); return text }
    return toString(lhs) == toString(rhs)
  }
}
