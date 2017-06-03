//
//  LayerTree.LayerTests.swift
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

class LayerTreeLayerTests: XCTestCase {
    
    typealias StrokeAttributes = LayerTree.StrokeAttributes
    typealias FillAttributes = LayerTree.FillAttributes
    typealias Layer = LayerTree.Layer
    typealias Contents = LayerTree.Layer.Contents
    
    func testStrokeAttributesEquality() {
        let a1 = StrokeAttributes(color: .black, width: 1.0, cap: .butt, join: .bevel, miterLimit: 1.0)
        let a2 = StrokeAttributes(color: .black, width: 2.0, cap: .butt, join: .bevel, miterLimit: 1.0)
        let a3 = StrokeAttributes(color: .white, width: 1.0, cap: .butt, join: .bevel, miterLimit: 1.0)
        
        XCTAssertEqual(a1, a1)
        XCTAssertEqual(a1, StrokeAttributes(color: .black, width: 1.0, cap: .butt, join: .bevel, miterLimit: 1.0))
        XCTAssertEqual(a2, a2)
        XCTAssertEqual(a2, StrokeAttributes(color: .black, width: 2.0, cap: .butt, join: .bevel, miterLimit: 1.0))
        XCTAssertEqual(a3, a3)
        XCTAssertEqual(a3, StrokeAttributes(color: .white, width: 1.0, cap: .butt, join: .bevel, miterLimit: 1.0))
        
        XCTAssertNotEqual(a1, a2)
        XCTAssertNotEqual(a2, a3)
        XCTAssertNotEqual(a2, a3)
    }
    
    func testFillAttributesEquality() {
        let a1 = FillAttributes(color: .black, rule: .evenodd)
        let a2 = FillAttributes(color: .white, rule: .nonzero)
        
        XCTAssertEqual(a1, a1)
        XCTAssertEqual(a1, FillAttributes(color: .black, rule: .evenodd))
        XCTAssertEqual(a2, a2)
        XCTAssertEqual(a2, FillAttributes(color: .white, rule: .nonzero))
        
        XCTAssertNotEqual(a1, a2)
    }
    
    func testContentsShapeEquality() {
        let c1 = Contents.shape(.line(between: [.zero]), .normal, .normal)
        
        var att = StrokeAttributes.normal
        att.color = .rgba(r: 1.0, g: 0, b: 0, a: 1.0)
        let c2 = Contents.shape(.line(between: [.zero]), att, .normal)
        let c3 = Contents.shape(.line(between: [LayerTree.Point(10,20)]), .normal, .normal)
        let c4 = Contents.shape(.line(between: [.zero]), .normal, FillAttributes(color: .white, rule: .evenodd))
        
        XCTAssertEqual(c1, c1)
        XCTAssertEqual(c1, .shape(.line(between: [.zero]), .normal, .normal))
        
        XCTAssertEqual(c2, c2)
        XCTAssertEqual(c2, .shape(.line(between: [.zero]), att, .normal))
        
        XCTAssertEqual(c3, c3)
        XCTAssertEqual(c3, .shape(.line(between: [LayerTree.Point(10,20)]), .normal, .normal))
        
        XCTAssertEqual(c4, c4)
        XCTAssertEqual(c4, .shape(.line(between: [.zero]), .normal, FillAttributes(color: .white, rule: .evenodd)))
        
        XCTAssertNotEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
        XCTAssertNotEqual(c1, c4)
        XCTAssertNotEqual(c2, c3)
        XCTAssertNotEqual(c2, c4)
        XCTAssertNotEqual(c3, c4)
    }
}
