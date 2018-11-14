//
//  LayerTree.TransformTests.swift
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

class LayerTreeTransformTests: XCTestCase {
    
    typealias Transform = LayerTree.Transform
    typealias Matrix = LayerTree.Transform.Matrix
    
    func testMatrixEquality() {
        let m1 = Matrix(a: 0, b: 1, c: 2, d: 3, tx: 4, ty: 5)
        let m2 = Matrix(a: 5, b: 4, c: 3, d: 2, tx: 1, ty: 0)
        let m3 = Transform.identity.toMatrix()
        
        XCTAssertEqual(m1, Matrix(a: 0, b: 1, c: 2, d: 3, tx: 4, ty: 5))
        XCTAssertEqual(m1, m1)
        XCTAssertEqual(m2, Matrix(a: 5, b: 4, c: 3, d: 2, tx: 1, ty: 0))
        XCTAssertEqual(m2, m2)
        XCTAssertEqual(m3, Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))
        XCTAssertEqual(m3, m3)
        
        XCTAssertNotEqual(m1, m2)
        XCTAssertNotEqual(m1, m3)
        XCTAssertNotEqual(m2, m3)
    }
    
    func testTransfromEquality() {
        let m1 = Matrix(a: 0, b: 1, c: 2, d: 3, tx: 4, ty: 5)
        let t1 = Transform.matrix(m1)
        let t2 = Transform.translate(tx: 1, ty: 2)
        let t3 = Transform.scale(sx: 3, sy: 4)
        let t4 = Transform.rotate(radians: Float.pi/2)
        
        XCTAssertEqual(t1, .matrix(m1))
        XCTAssertEqual(t1, t1)
        XCTAssertEqual(t2, .translate(tx: 1, ty: 2))
        XCTAssertEqual(t2, t2)
        XCTAssertEqual(t3, .scale(sx: 3, sy: 4))
        XCTAssertEqual(t3, t3)
        XCTAssertEqual(t4, .rotate(radians: Float.pi/2))
        XCTAssertEqual(t4, t4)
        
        XCTAssertNotEqual(t1, t2)
        XCTAssertNotEqual(t1, t3)
        XCTAssertNotEqual(t1, t4)
        XCTAssertNotEqual(t2, t3)
        XCTAssertNotEqual(t2, t4)
        XCTAssertNotEqual(t3, t4)
    }
}
