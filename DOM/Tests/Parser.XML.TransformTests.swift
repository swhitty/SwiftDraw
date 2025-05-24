//
//  Parser.XML.TransformTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
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
@testable import DOM

final class ParserTransformTests: XCTestCase {
  
  func testMatrix() {
    XCTAssertEqual(try XMLParser().parseTransform("matrix(0 1 2 3 4 5)"),
                   [.matrix(a: 0, b: 1, c: 2, d: 3, e: 4, f: 5)])
    XCTAssertEqual(try XMLParser().parseTransform("matrix(0,1,2,3,4,5)"),
                   [.matrix(a: 0, b: 1, c: 2, d: 3, e: 4, f: 5)])
    XCTAssertEqual(try XMLParser().parseTransform("matrix(1.1,1.2,1.3,1.4,1.5,1.6)"),
                   [.matrix(a: 1.1, b: 1.2, c: 1.3, d: 1.4, e: 1.5, f: 1.6)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("matrix(0 1 a b 4 5)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("matrix(0 1 2)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("matrix(0 1 2 3 4 5"))
    XCTAssertThrowsError(try XMLParser().parseTransform("matrix 0 1 2 3 4 5)"))
  }
  
  func testTranslate() {
    XCTAssertEqual(try XMLParser().parseTransform("translate(5)"),
                   [.translate(tx: 5, ty: 0)])
    XCTAssertEqual(try XMLParser().parseTransform("translate(5, 6)"),
                   [.translate(tx: 5, ty: 6)])
    XCTAssertEqual(try XMLParser().parseTransform("translate(5 6)"),
                   [.translate(tx: 5, ty: 6)])
    XCTAssertEqual(try XMLParser().parseTransform("translate(1.3, 4.5)"),
                   [.translate(tx: 1.3, ty: 4.5)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("translate(5 a)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("translate(0 1 2)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("translate(0 1"))
    XCTAssertThrowsError(try XMLParser().parseTransform("translate 0 1)"))
  }
  
  func testScale() {
    XCTAssertEqual(try XMLParser().parseTransform("scale(5)"),
                   [.scale(sx: 5, sy: 5)])
    XCTAssertEqual(try XMLParser().parseTransform("scale(5, 6)"),
                   [.scale(sx: 5, sy: 6)])
    XCTAssertEqual(try XMLParser().parseTransform("scale(5 6)"),
                   [.scale(sx: 5, sy: 6)])
    XCTAssertEqual(try XMLParser().parseTransform("scale(1.3, 4.5)"),
                   [.scale(sx: 1.3, sy: 4.5)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("scale(5 a)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("scale(0 1 2)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("scale(0 1"))
    XCTAssertThrowsError(try XMLParser().parseTransform("scale 0 1)"))
  }
  
  func testRotate() {
    XCTAssertEqual(try XMLParser().parseTransform("rotate(5)"),
                   [.rotate(angle: 5)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate(a)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate()"))
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate(1"))
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate 1)"))
  }
  
  func testRotatePoint() {
    XCTAssertEqual(try XMLParser().parseTransform("rotate(5, 10, 20)"),
                   [.rotatePoint(angle: 5, cx: 10, cy: 20)])
    XCTAssertEqual(try XMLParser().parseTransform("rotate(5 10 20)"),
                   [.rotatePoint(angle: 5, cx: 10, cy: 20)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate(5 10 a)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate(5 10)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate(5 10 20"))
    XCTAssertThrowsError(try XMLParser().parseTransform("rotate 5 10 20)"))
  }
  
  func testSkewX() {
    XCTAssertEqual(try XMLParser().parseTransform("skewX(5)"),
                   [.skewX(angle: 5)])
    XCTAssertEqual(try XMLParser().parseTransform("skewX(6.7)"),
                   [.skewX(angle: 6.7)])
    XCTAssertEqual(try XMLParser().parseTransform("skewX(0)"),
                   [.skewX(angle: 0)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("skewX(a)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("skewX()"))
    XCTAssertThrowsError(try XMLParser().parseTransform("skewX(1"))
    XCTAssertThrowsError(try XMLParser().parseTransform("skewX 1)"))
  }
  
  func testSkewY() {
    XCTAssertEqual(try XMLParser().parseTransform("skewY(5)"),
                   [.skewY(angle: 5)])
    XCTAssertEqual(try XMLParser().parseTransform("skewY(6.7)"),
                   [.skewY(angle: 6.7)])
    XCTAssertEqual(try XMLParser().parseTransform("skewY(0)"),
                   [.skewY(angle: 0)])
    
    XCTAssertThrowsError(try XMLParser().parseTransform("skewY(a)"))
    XCTAssertThrowsError(try XMLParser().parseTransform("skewY()"))
    XCTAssertThrowsError(try XMLParser().parseTransform("skewY(1"))
    XCTAssertThrowsError(try XMLParser().parseTransform("skewY 1)"))
  }
  
  func testTransform() {
    XCTAssertEqual(try XMLParser().parseTransform("scale(2) translate(4) scale(5, 5) "),
                   [.scale(sx: 2, sy: 2),
                    .translate(tx: 4, ty: 0),
                    .scale(sx: 5, sy: 5)])
  }
}
