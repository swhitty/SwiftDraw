//
//  Renderer.CoreGraphicsTypesTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
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

class RendererCoreGraphicsTypesTests: XCTestCase {
    
    typealias Float = LayerTree.Float
    
    func testFloat() {
        XCTAssertEqual(CGProvider().createFloat(from: Float(10)), 10.0)
        XCTAssertEqual(CGProvider().createFloat(from: Float(200.5)), 200.5)
    }
    
    func testPoint() {
        XCTAssertEqual(CGProvider().createPoint(from: LayerTree.Point(10, 20)), CGPoint(x: 10, y: 20))
        XCTAssertEqual(CGProvider().createPoint(from: LayerTree.Point(200.5, 300.5)), CGPoint(x: 200.5, y: 300.5))
    }
    
    func testSize() {
        XCTAssertEqual(CGProvider().createSize(from: LayerTree.Size(10, 20)), CGSize(width: 10, height: 20))
        XCTAssertEqual(CGProvider().createSize(from: LayerTree.Size(200.5, 300.5)), CGSize(width: 200.5, height: 300.5))
    }
    
    func testRect() {
        let r1 = LayerTree.Rect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(CGProvider().createRect(from: r1),
                       CGRect(x: 10, y: 20, width: 30, height: 40))
        
        let r2 = LayerTree.Rect(x: 200.5, y: 300.5, width: 400.5, height: 500.5)
        XCTAssertEqual(CGProvider().createRect(from: r2),
                       CGRect(x: 200.5, y: 300.5, width: 400.5, height: 500.5))
    }
    
    func testColor() {
        let c = CGProvider().createColor(from: .rgba(r: 0.1, g: 0.2, b: 0.3, a: 0.4))
        //CGFloat(Float(xx)) accounts for floating point margin of error
        let reference = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [CGFloat(Float(0.1)), CGFloat(Float(0.2)), CGFloat(Float(0.3)), CGFloat(Float(0.4))])!
        XCTAssertEqual(c.components!, reference.components!)
        
        let clear = CGProvider().createColor(from: .none)
        //CGFloat(Float(xx)) accounts for floating point margin of error
        let clearReference = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0, 0, 0, 0])!
        XCTAssertEqual(clear.components!, clearReference.components!)
    }
    
    func testTransform() {
        let t1 = LayerTree.Transform(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60)
        let expected = CGAffineTransform(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60)
        XCTAssertEqual(CGProvider().createTransform(from: t1), expected)
    }
    
    func testBlendMode() {
        XCTAssertEqual(CGProvider().createBlendMode(from: .normal), .normal)
        XCTAssertEqual(CGProvider().createBlendMode(from: .copy), .copy)
        XCTAssertEqual(CGProvider().createBlendMode(from: .sourceIn), .sourceIn)
    }
    
    func testFillRule() {
        XCTAssertEqual(CGProvider().createFillRule(from: .nonzero), .winding)
        XCTAssertEqual(CGProvider().createFillRule(from: .evenodd), .evenOdd)
    }
    
    func testLineCap() {
        XCTAssertEqual(CGProvider().createLineCap(from: .butt), .butt)
        XCTAssertEqual(CGProvider().createLineCap(from: .round), .round)
        XCTAssertEqual(CGProvider().createLineCap(from: .square), .square)
    }
    
    func testLineJoin() {
        XCTAssertEqual(CGProvider().createLineJoin(from: .miter), .miter)
        XCTAssertEqual(CGProvider().createLineJoin(from: .round), .round)
        XCTAssertEqual(CGProvider().createLineJoin(from: .bevel), .bevel)
    }
    
//TODO: verify these within type provider
//    func createPath(from shape: LayerTree.Shape) -> CGPath
//    func createPath(from subPaths: [CGPath]) -> CGPath
//    func createPath(from text: String, with font: String, at origin: Types.Point, ofSize pt: Types.Float) -> CGPath?
//    func createImage(from image: LayerTree.Image) -> CGImage?
    
}
