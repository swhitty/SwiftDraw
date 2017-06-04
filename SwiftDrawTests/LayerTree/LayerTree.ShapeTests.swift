//
//  LayerTree.ShapeTests.swift
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

class LayerTreeShapeTests: XCTestCase {
    
    typealias Point = LayerTree.Point
    typealias Rect = LayerTree.Rect
    typealias Size = LayerTree.Size
    typealias Path = LayerTree.Path
    
    func testShapeEquality() {
        let s1 = LayerTree.Shape.line(between: [.zero, Point(100, 200)])
        let s2 = LayerTree.Shape.rect(within: .zero, radii: Size(10, 20))
        let s3 = LayerTree.Shape.ellipse(within: .zero)
        let s4 = LayerTree.Shape.polygon(between: [.zero, Point(10, 20)])
        let s5 = LayerTree.Shape.path(Path())
        
        XCTAssertEqual(s1, s1)
        XCTAssertEqual(s1, .line(between: [.zero, Point(100, 200)]))
        XCTAssertNotEqual(s1, .line(between: []))
        
        XCTAssertEqual(s2, s2)
        XCTAssertEqual(s2, .rect(within: .zero, radii: Size(10, 20)))
        XCTAssertNotEqual(s2, .rect(within: .zero, radii: .zero))
        
        XCTAssertEqual(s3, s3)
        XCTAssertEqual(s3, .ellipse(within: .zero))
        XCTAssertNotEqual(s3, .ellipse(within: Rect(x: 0, y: 0, width: 10, height: 20)))
        
        XCTAssertEqual(s4, s4)
        XCTAssertEqual(s4, .polygon(between: [.zero, Point(10, 20)]))
        XCTAssertNotEqual(s4, .polygon(between: []))
        
        XCTAssertEqual(s5, s5)
        XCTAssertEqual(s5, .path(Path()))
        XCTAssertNotEqual(s5, .path(Path([.close])))
        
        XCTAssertNotEqual(s1, s2)
        XCTAssertNotEqual(s1, s3)
        XCTAssertNotEqual(s1, s4)
        XCTAssertNotEqual(s1, s5)
        
        XCTAssertNotEqual(s2, s3)
        XCTAssertNotEqual(s2, s4)
        XCTAssertNotEqual(s2, s5)
        
        XCTAssertNotEqual(s3, s4)
        XCTAssertNotEqual(s3, s5)
        
        XCTAssertNotEqual(s4, s5)
    }
    
    func testLineBuilder() {
        let line = DOM.Line(x1: 10, y1: 20, x2: 30, y2: 40)
        let shape = LayerTree.Builder.createShape(from: line)
        
        XCTAssertEqual(shape, .line(between: [Point(10, 20), Point(30, 40)]))
    }
    
    func testCircleBuilder() {
        let cicle = DOM.Circle(cx: 50, cy: 50, r: 25)
        let shape = LayerTree.Builder.createShape(from: cicle)
        
        XCTAssertEqual(shape, .ellipse(within: Rect(x: 25, y: 25, width: 50, height: 50)))
    }
    
    func testEllipseBuilder() {
        let ellipse = DOM.Ellipse(cx: 50, cy: 75, rx: 25, ry: 50)
        let shape = LayerTree.Builder.createShape(from: ellipse)
        
        XCTAssertEqual(shape, .ellipse(within: Rect(x: 25, y: 25, width: 50, height: 100)))
    }
    
    func testRectBuilder() {
        let rect = DOM.Rect(x: 10, y: 20, width: 30, height: 40)
        let shape = LayerTree.Builder.createShape(from: rect)
        XCTAssertEqual(shape, .rect(within: Rect(x: 10, y: 20, width: 30, height: 40),
                                    radii: .zero))
        
        //add corner radii
        rect.rx = 2
        rect.ry = 4
        let another = LayerTree.Builder.createShape(from: rect)
        XCTAssertEqual(another, .rect(within: Rect(x: 10, y: 20, width: 30, height: 40),
                                      radii: Size(2, 4)))
    }
    
    func testPolylineBuilder() {
        let line = DOM.Polyline(10,20,30,40,50,60)
        let shape = LayerTree.Builder.createShape(from: line)
        
        XCTAssertEqual(shape, .line(between: [Point(10, 20), Point(30, 40), Point(50, 60)]))
    }
    
}
