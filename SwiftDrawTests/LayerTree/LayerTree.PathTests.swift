//
//  LayerTree.PathTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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

class LayerTreePathTests: XCTestCase {
    
    typealias Point = LayerTree.Point
    
    func testSegmentEquality() {
        let move1 = LayerTree.Path.Segment.move(to: .zero)
        let move2 = LayerTree.Path.Segment.move(to: Point(10, 20))
        let line1 = LayerTree.Path.Segment.line(to: .zero)
        let line2 = LayerTree.Path.Segment.line(to: Point(10, 20))
        let cubic1 = LayerTree.Path.Segment.cubic(to: .zero,
                                                  control1: Point(10, 20),
                                                  control2: Point(30, 40))
        let cubic2 = LayerTree.Path.Segment.cubic(to: Point(40, 30),
                                                  control1: Point(20, 10),
                                                  control2: .zero)
        let close = LayerTree.Path.Segment.close
        
        XCTAssertEqual(move1, move1)
        XCTAssertEqual(move1, .move(to: .zero))
        XCTAssertEqual(move2, move2)
        XCTAssertEqual(move2, .move(to: Point(10, 20)))
        
        XCTAssertEqual(line1, line1)
        XCTAssertEqual(line1, .line(to: .zero))
        XCTAssertEqual(line2, line2)
        XCTAssertEqual(line2, .line(to: Point(10, 20)))
        
        XCTAssertEqual(cubic1, cubic1)
        XCTAssertEqual(cubic1, .cubic(to: .zero, control1: Point(10, 20), control2: Point(30, 40)))
        XCTAssertEqual(cubic2, cubic2)
        XCTAssertEqual(cubic2, .cubic(to: Point(40, 30), control1: Point(20, 10), control2: .zero))

        XCTAssertEqual(close, close)
        XCTAssertEqual(close, .close)
        
        XCTAssertNotEqual(move1, move2)
        XCTAssertNotEqual(move1, line1)
        XCTAssertNotEqual(move1, line2)
        XCTAssertNotEqual(move1, cubic1)
        XCTAssertNotEqual(move1, cubic2)
        XCTAssertNotEqual(move1, close)
        XCTAssertNotEqual(move2, line1)
        XCTAssertNotEqual(move2, line2)
        XCTAssertNotEqual(move2, cubic1)
        XCTAssertNotEqual(move2, cubic2)
        XCTAssertNotEqual(move2, close)
        XCTAssertNotEqual(line1, line2)
        XCTAssertNotEqual(line1, cubic1)
        XCTAssertNotEqual(line1, cubic2)
        XCTAssertNotEqual(line1, close)
        XCTAssertNotEqual(line2, cubic1)
        XCTAssertNotEqual(line2, cubic2)
        XCTAssertNotEqual(line2, close)
        XCTAssertNotEqual(cubic1, cubic2)
        XCTAssertNotEqual(cubic1, close)
        XCTAssertNotEqual(cubic2, close)
    }
    
    func testPathEquality() {
        
        let p1 = LayerTree.Path()
        let p2 = LayerTree.Path([.move(to: .zero), .line(to: Point(100,100)), .close])
        let p3 = LayerTree.Path([.move(to: .zero), .close])

        XCTAssertEqual(p1, p1)
        XCTAssertEqual(p1, LayerTree.Path())
        
        XCTAssertEqual(p2, p2)
        XCTAssertEqual(p2, LayerTree.Path([.move(to: .zero), .line(to: Point(100,100)), .close]))
        
        XCTAssertEqual(p3, p3)
        XCTAssertEqual(p3, LayerTree.Path([.move(to: .zero), .close]))
        
        XCTAssertNotEqual(p1, p2)
        XCTAssertNotEqual(p1, p3)
        XCTAssertNotEqual(p2, p3)
    }
}
