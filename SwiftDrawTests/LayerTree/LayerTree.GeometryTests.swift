//
//  LayerTree.ColorTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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

class LayerTreeGeometryTests: XCTestCase {
    
    func testPointEquality() {
        let p1 = LayerTree.Point(10.0, 20.0)
        let p2 = LayerTree.Point(20.0, 10.0)
        let p3 = LayerTree.Point(0.0, 0.0)
    
        XCTAssertEqual(p1, LayerTree.Point(10.0, 20.0))
        XCTAssertEqual(p1, p1)
        XCTAssertEqual(p2, LayerTree.Point(20.0, 10.0))
        XCTAssertEqual(p2, p2)
        XCTAssertEqual(p3, .zero)
        XCTAssertEqual(p3, p3)
        
        XCTAssertNotEqual(p1, p2)
        XCTAssertNotEqual(p1, p3)
        XCTAssertNotEqual(p2, p3)
    }
    
    func testPointHashValue() {
        let p1 = LayerTree.Point(10.0, 20.0)
        let p2 = LayerTree.Point(20.0, 10.0)
        let p3 = LayerTree.Point(0.0, 0.0)
        
        XCTAssertNotEqual(p1.hashValue, p2.hashValue)
        XCTAssertNotEqual(p1.hashValue, p3.hashValue)
        XCTAssertNotEqual(p2.hashValue, p3.hashValue)
    }
    
    func testSizeEquality() {
        let s1 = LayerTree.Size(10.0, 20.0)
        let s2 = LayerTree.Size(20.0, 10.0)
        let s3 = LayerTree.Size(0.0, 0.0)
        
        XCTAssertEqual(s1, LayerTree.Size(10.0, 20.0))
        XCTAssertEqual(s1, s1)
        XCTAssertEqual(s2, LayerTree.Size(20.0, 10.0))
        XCTAssertEqual(s2, s2)
        XCTAssertEqual(s3, .zero)
        XCTAssertEqual(s3, s3)
        
        XCTAssertNotEqual(s1, s2)
        XCTAssertNotEqual(s1, s3)
        XCTAssertNotEqual(s2, s3)
    }
    
    func testSizeHashValue() {
        let s1 = LayerTree.Size(10.0, 20.0)
        let s2 = LayerTree.Size(20.0, 10.0)
        let s3 = LayerTree.Size(0.0, 0.0)
        
        XCTAssertNotEqual(s1.hashValue, s2.hashValue)
        XCTAssertNotEqual(s1.hashValue, s3.hashValue)
        XCTAssertNotEqual(s2.hashValue, s3.hashValue)
    }
    
    func testRectEquality() {
        let r1 = LayerTree.Rect(x: 10.0, y: 20.0, width: 30.0, height: 40.0)
        let r2 = LayerTree.Rect(x: 40.0, y: 30.0, width: 20.0, height: 10.0)
        let r3 = LayerTree.Rect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        
        XCTAssertEqual(r1, LayerTree.Rect(x: 10.0, y: 20.0, width: 30.0, height: 40.0))
        XCTAssertEqual(r1, r1)
        XCTAssertEqual(r2, LayerTree.Rect(x: 40.0, y: 30.0, width: 20.0, height: 10.0))
        XCTAssertEqual(r2, r2)
        XCTAssertEqual(r3, .zero)
        XCTAssertEqual(r3, r3)
        
        XCTAssertNotEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
        XCTAssertNotEqual(r2, r3)
    }
    
    func testRectHashValue() {
        let r1 = LayerTree.Rect(x: 10.0, y: 20.0, width: 30.0, height: 40.0)
        let r2 = LayerTree.Rect(x: 40.0, y: 30.0, width: 20.0, height: 10.0)
        let r3 = LayerTree.Rect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        
        XCTAssertNotEqual(r1.hashValue, r2.hashValue)
        XCTAssertNotEqual(r1.hashValue, r3.hashValue)
        XCTAssertNotEqual(r2.hashValue, r3.hashValue)
    }
}
