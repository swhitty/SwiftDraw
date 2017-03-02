//
//  PathTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG

private func AssertScanCommand(_ text: String, _ command: SwiftVG.Formatter.XML.Path.Command, file: StaticString = #file, line: UInt = #line) {
    var scanner = XMLParser.PathScanner(data: text)
    XCTAssertEqual(try? scanner.scanCommand(), command, file: file, line: line)
}

private func AssertScanSegment(_ text: String, _ segment: DOM.Path.Segment, file: StaticString = #file, line: UInt = #line) {
    var scanner = XMLParser.PathScanner(data: text)
    XCTAssertEqual(try? scanner.scanSegment(), segment, file: file, line: line)
}

class PathTests: XCTestCase {
    
    func testPath() {
        let node: Attributes = ["d": "M 10 10 h 10 v 10 h -10 v -10"]
        let parser = XMLParser()
        
        let path = try! parser.parsePath(node)
        
        XCTAssertEqual(path.segments.count, 5)
        
        XCTAssertEqual(path.segments[0], .move(DOM.Path.Move(10, 10), .absolute))
        XCTAssertEqual(path.segments[1], .horizontal(DOM.Path.Horizontal(10), .relative))
        XCTAssertEqual(path.segments[2], .vertical(DOM.Path.Vertical(10), .relative))
        XCTAssertEqual(path.segments[3], .horizontal(DOM.Path.Horizontal(-10), .relative))
        XCTAssertEqual(path.segments[4], .vertical(DOM.Path.Vertical(-10), .relative))
    }
    
    func testPathFillRule() {
        
        let node = XML.Element(name: "path")
        node.attributes["d"] = "M 10 10"
        XCTAssertNil((try! XMLParser().parseGraphicsElement(node))!.fillRule)
        
        node.attributes["fill-rule"] = "nonzero"
        XCTAssertEqual(try XMLParser().parseGraphicsElement(node)!.fillRule, .nonzero)
        
        node.attributes["fill-rule"] = "evenodd"
        XCTAssertEqual(try XMLParser().parseGraphicsElement(node)!.fillRule, .evenodd)
        
        node.attributes["fill-rule"] = "asdf"
        XCTAssertThrowsError(try XMLParser().parseGraphicsElement(node)!.fillRule)
    }
    
    func testScanMove() {
        var scanner = XMLParser.PathScanner(data: "10 20")
        XCTAssertEqual(DOM.Path.Move(10, 20), try? scanner.scanMove())
        
        scanner = XMLParser.PathScanner(data: "10 f")
        XCTAssertThrowsError(try scanner.scanMove())
    }
    
    func testScanLine() {
        var scanner = XMLParser.PathScanner(data: "10 20")
        XCTAssertEqual(DOM.Path.Line(10, 20), try? scanner.scanLine())
        
        scanner = XMLParser.PathScanner(data: "10 f")
        XCTAssertThrowsError(try scanner.scanLine())
    }
    
    func testScanHorizontal() {
        var scanner = XMLParser.PathScanner(data: "10")
        XCTAssertEqual(DOM.Path.Horizontal(10), try? scanner.scanHorizontal())
        
        scanner = XMLParser.PathScanner(data: "f")
        XCTAssertThrowsError(try scanner.scanHorizontal())
    }
    
    func testScanVertical() {
        var scanner = XMLParser.PathScanner(data: "10")
        XCTAssertEqual(DOM.Path.Vertical(10), try? scanner.scanVertical())
        
        scanner = XMLParser.PathScanner(data: "f")
        XCTAssertThrowsError(try scanner.scanVertical())
    }
    
    func testScanCubic() {
        var scanner = XMLParser.PathScanner(data: "10 20 30 40 50 60")
        XCTAssertEqual(DOM.Path.Cubic(10, 20, 30, 40, 50, 60), try? scanner.scanCubic())
        
        scanner = XMLParser.PathScanner(data: "10 20 30 40 50 f")
        XCTAssertThrowsError(try scanner.scanCubic())
    }
    
    func testScanCubicSmooth() {
        var scanner = XMLParser.PathScanner(data: "10 20 30 40")
        XCTAssertEqual(DOM.Path.CubicSmooth(10, 20, 30, 40), try? scanner.scanCubicSmooth())
        
        scanner = XMLParser.PathScanner(data: "10 20 30 f")
        XCTAssertThrowsError(try scanner.scanCubicSmooth())
    }
    
    func testScanQuadratic() {
        var scanner = XMLParser.PathScanner(data: "10 20 30 40")
        XCTAssertEqual(DOM.Path.Quadratic(10, 20, 30, 40), try? scanner.scanQuadratic())
        
        scanner = XMLParser.PathScanner(data: "10 20 30 f")
        XCTAssertThrowsError(try scanner.scanQuadratic())
    }
    
    func testScanQuadraticSmooth() {
        var scanner = XMLParser.PathScanner(data: "10 20")
        XCTAssertEqual(DOM.Path.QuadraticSmooth(10, 20), try? scanner.scanQuadraticSmooth())
        
        scanner = XMLParser.PathScanner(data: "10 f")
        XCTAssertThrowsError(try scanner.scanQuadraticSmooth())
    }
    
    func testScanArc() {
        var scanner = XMLParser.PathScanner(data: "10 20 30 40 50 1 0")
        XCTAssertEqual(DOM.Path.Arc(10, 20, 30, 40, 50, true, false), try? scanner.scanArc())
        
        scanner = XMLParser.PathScanner(data: "10 20 30 f")
        XCTAssertThrowsError(try scanner.scanArc())
    }
    
    func testScanCommand() {
        AssertScanCommand("M", .move)
        AssertScanCommand("m", .moveRelative)
        AssertScanCommand("L", .line)
        AssertScanCommand("l", .lineRelative)
        AssertScanCommand("H", .horizontal)
        AssertScanCommand("h", .horizontalRelative)
        AssertScanCommand("V", .vertical)
        AssertScanCommand("v", .verticalRelative)
        AssertScanCommand("C", .cubic)
        AssertScanCommand("c", .cubicRelative)
        AssertScanCommand("S", .cubicSmooth)
        AssertScanCommand("s", .cubicSmoothRelative)
        AssertScanCommand("Q", .quadratic)
        AssertScanCommand("q", .quadraticRelative)
        AssertScanCommand("T", .quadraticSmooth)
        AssertScanCommand("t", .quadraticSmoothRelative)
        AssertScanCommand("A", .arc)
        AssertScanCommand("a", .arcRelative)
        AssertScanCommand("Z", .close)
        AssertScanCommand("z", .closeAlias)
        
        // leading whitespace is ignored
        AssertScanCommand(" M", .move)
        AssertScanCommand("\t  C", .cubic)
        AssertScanCommand("  \t  H", .horizontal)
    }
    
    func testScanSegment() {
        AssertScanSegment("M 10 20", .move(DOM.Path.Move(10, 20), .absolute))
        AssertScanSegment("m10;20", .move(DOM.Path.Move(10, 20), .relative))
        AssertScanSegment("L 10 20", .line(DOM.Path.Line(10, 20), .absolute))
        AssertScanSegment("l10;20", .line(DOM.Path.Line(10, 20), .relative))
        AssertScanSegment("V 10", .vertical(DOM.Path.Vertical(10), .absolute))
        AssertScanSegment("v 10", .vertical(DOM.Path.Vertical(10), .relative))
        AssertScanSegment("H 10", .horizontal(DOM.Path.Horizontal(10), .absolute))
        AssertScanSegment("h 10", .horizontal(DOM.Path.Horizontal(10), .relative))
        AssertScanSegment("C1;2;3;4;5;6;", .cubic(DOM.Path.Cubic(1, 2, 3, 4, 5, 6), .absolute))
        AssertScanSegment("c 1 2 3 4 5 6 ", .cubic(DOM.Path.Cubic(1, 2, 3, 4, 5, 6), .relative))
        AssertScanSegment("S1;2;3;4;", .cubicSmooth(DOM.Path.CubicSmooth(1, 2, 3, 4), .absolute))
        AssertScanSegment("s 1 2 3 4 ", .cubicSmooth(DOM.Path.CubicSmooth(1, 2, 3, 4), .relative))
        AssertScanSegment("Q1;2;3;4", .quadratic(DOM.Path.Quadratic(1, 2, 3, 4), .absolute))
        AssertScanSegment("q 1 2 3 4 ", .quadratic(DOM.Path.Quadratic(1, 2, 3, 4), .relative))
        AssertScanSegment("T1;2;", .quadraticSmooth(DOM.Path.QuadraticSmooth(1, 2), .absolute))
        AssertScanSegment("t 1 2 ", .quadraticSmooth(DOM.Path.QuadraticSmooth(1, 2), .relative))
        AssertScanSegment("A1;2;3;4;5;1;0", .arc(DOM.Path.Arc(1, 2, 3, 4, 5, true, false), .absolute))
        AssertScanSegment("a 1 2 3 4 5 1 0 ", .arc(DOM.Path.Arc(1, 2, 3, 4, 5, true, false), .relative))
        AssertScanSegment("Z", .close)
        AssertScanSegment("z", .close)
    }
    
}
