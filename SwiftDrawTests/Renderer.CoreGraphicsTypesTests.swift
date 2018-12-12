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
import CoreGraphics
@testable import SwiftDraw

final class RendererCoreGraphicsTypesTests: XCTestCase {
    
    typealias Float = LayerTree.Float
    typealias Point = LayerTree.Point
    typealias Rect = LayerTree.Rect
    typealias Size = LayerTree.Size
    
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
        let m = LayerTree.Transform.Matrix(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60)
        let expected = CGAffineTransform(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60)
        XCTAssertEqual(CGProvider().createTransform(from: m), expected)
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
    
    func testShapeLine() {
        let path = CGProvider().createPath(from: .line(between: [.zero, Point(10, 20), Point(30, 40)]))
        let segments: [CGPath.Segment] = [.move(CGPoint(0, 0)), .line(CGPoint(10, 20)), .line(CGPoint(30, 40))]
        XCTAssertEqual(path.segments(), segments)
    }
    
    func testShapeRect() {
        let path = CGProvider().createPath(from: .rect(within: Rect(x: 10, y: 20, width: 30, height: 40),
                                                       radii: Size(2, 4)))
        
        let expected = CGPath(roundedRect: CGRect(x:10, y: 20, width: 30, height: 40),
                              cornerWidth: 2.0,
                              cornerHeight: 4.0,
                              transform: nil)
        
        XCTAssertEqual(path, expected)
    }
    
    func testShapeEllipse() {
        let path = CGProvider().createPath(from: .ellipse(within: Rect(x: 10, y: 20, width: 30, height: 40)))
        let expected = CGPath(ellipseIn: CGRect(x:10, y: 20, width: 30, height: 40), transform: nil)
        XCTAssertEqual(path, expected)
    }
    
    func testShapePolygon() {
        let path = CGProvider().createPath(from: .polygon(between:
            [.zero,
             Point(0, 20),
             Point(20, 20),
             Point(20, 0)]))
        let expected = CGMutablePath()
        expected.move(to: CGPoint(x: 0, y: 0))
        expected.addLine(to: CGPoint(x: 0, y: 20))
        expected.addLine(to: CGPoint(x: 20, y: 20))
        expected.addLine(to: CGPoint(x: 20, y: 0))
        expected.closeSubpath()

        XCTAssertEqual(path.segments(), expected.segments())
    }
    
    func testShapePath() {
        let model = LayerTree.Path()
        model.segments.append(.move(to: Point(0, 0)))
        model.segments.append(.line(to: Point(100, 100)))
        model.segments.append(.cubic(to: Point(100, 0), control1: Point(50, 75), control2: Point(150, 25)))
        model.segments.append(.close)
        
        let expected = CGMutablePath()
        expected.move(to: CGPoint(x: 0, y: 0))
        expected.addLine(to: CGPoint(x: 100, y: 100))
        expected.addCurve(to: CGPoint(x: 100, y: 0), control1: CGPoint(x: 50, y: 75), control2: CGPoint(x: 150, y: 25))
        expected.closeSubpath()
        
        let path = CGProvider().createPath(from: .path(model))
        XCTAssertEqual(path, expected)
    }

    func testTextPath() {
        XCTAssertNotNil(CGProvider().createPath(from: "Hi", at: .zero, with: .normal))
    }

    func testSubpath() {
        let p1 = CGMutablePath()
        p1.move(to: CGPoint(x: 0, y: 0))
        p1.addLine(to: CGPoint(x: 100, y: 100))
        p1.closeSubpath()

        let p2 = CGMutablePath()
        p2.move(to: CGPoint(x: 100, y: 0))
        p2.addLine(to: CGPoint(x: 200, y: 200))
        p2.closeSubpath()

        let segments = CGProvider().createPath(from: [p1, p2]).segments()
        XCTAssertEqual(segments, [.move(CGPoint(x: 0, y: 0)),
                                  .line(CGPoint(x: 100, y: 100)),
                                  .close,
                                  .move(CGPoint(x: 100, y: 0)),
                                  .line(CGPoint(x: 200, y: 200)),
                                  .close])
    }

//TODO: verify these within type provider

//    func createImage(from image: LayerTree.Image) -> CGImage?
    
}

private extension CGPoint {
    init(_ x: CGFloat, _ y: CGFloat) {
        self.init(x: x, y: y)
    }
    init(_ x: Int, _ y: Int) {
        self.init(x: x, y: y)
    }
}
