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

final class LayerTreeTransformTests: XCTestCase {
    
    private typealias Transform = LayerTree.Transform
    private typealias Matrix = LayerTree.Transform.Matrix

    func testSkewXMatrix() {
        let transform = Transform.skewX(angle: LayerTree.Float.pi/4)
        XCTAssertEqual(transform.toMatrix(), Matrix(a: 1, b: 0, c: tan(LayerTree.Float.pi/4), d: 1, tx: 0, ty: 0))
    }

    func testSkewYMatrix() {
        let transform = Transform.skewY(angle: LayerTree.Float.pi/4)
        XCTAssertEqual(transform.toMatrix(), Matrix(a: 1, b: tan(LayerTree.Float.pi/4), c: 0, d: 1, tx: 0, ty: 0))
    }

    func testScaleMatrix() {
        let transform = Transform.scale(sx: 2.0, sy: 3.0)
        XCTAssertEqual(transform.toMatrix(), Matrix(a: 2.0, b: 0, c: 0, d: 3.0, tx: 0, ty: 0))
    }

    func testTranslateMatrix() {
        let transform = Transform.translate(tx: 2.0, ty: 3.0)
        XCTAssertEqual(transform.toMatrix(), Matrix(a: 1, b: 0, c: 0, d: 1, tx: 2.0, ty: 3.0))
    }

    func testRotateMatrix() {
        let angle = LayerTree.Float.pi/4
        let transform = Transform.rotate(radians: angle)
        XCTAssertEqual(transform.toMatrix(),
                       Matrix(a: cos(angle), b: sin(angle), c: -sin(angle), d: cos(angle), tx: 0, ty: 0))
    }

    func testMatrixConcatenation() {
        let concatenated = Transform.identity.toMatrix().concatenated(Transform.identity.toMatrix())
        XCTAssertEqual(concatenated, Transform.identity.toMatrix())
    }

    func testDOMMakesLayerTreeTranslate() {
        let translate = DOM.Transform.translate(tx: 10, ty: 20)
        let transform = LayerTree.Builder.createTransform(for: translate)

        XCTAssertEqual(transform, [.translate(tx: 10, ty: 20)])
    }

    func testDOMMakesScaleTransform() {
        let scale = DOM.Transform.scale(sx: 10, sy: 20)
        let transform = LayerTree.Builder.createTransform(for: scale)

        XCTAssertEqual(transform, [.scale(sx: 10, sy: 20)])
    }

    func testDOMMakesRotateTransform() {
        let rotate = DOM.Transform.rotate(angle: 10)
        let transform = LayerTree.Builder.createTransform(for: rotate)

        let radians = 10*Float.pi/180.0
        XCTAssertEqual(transform, [.rotate(radians: radians)])
    }

    func testDOMMakesRotatePointTransform() {
        let rotate = DOM.Transform.rotatePoint(angle: 10, cx: 20, cy: 30)
        let transform = LayerTree.Builder.createTransform(for: rotate)

        let radians = 10*Float.pi/180.0
        XCTAssertEqual(transform, [.translate(tx: 20, ty: 30),
                                   .rotate(radians: radians),
                                   .translate(tx: -20, ty: -30)])
    }

    func testDOMMakesSkewXTransform() {
        let skew = DOM.Transform.skewX(angle: 10)
        let transform = LayerTree.Builder.createTransform(for: skew)

        let radians = 10*Float.pi/180.0
        XCTAssertEqual(transform, [.skewX(angle: radians)])
    }

    func testDOMMakesSkewYTransform() {
        let skew = DOM.Transform.skewY(angle: 10)
        let transform = LayerTree.Builder.createTransform(for: skew)

        let radians = 10*Float.pi/180.0
        XCTAssertEqual(transform, [.skewY(angle: radians)])
    }

    func testDOMMakesMatrixTransform() {
        let matrix = DOM.Transform.matrix(a: 10, b: 20, c: 30, d: 40, e: 50, f: 60)
        let transform = LayerTree.Builder.createTransform(for: matrix)

        let expected = Matrix(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60)
        XCTAssertEqual(transform, [.matrix(expected)])
    }

    func testDOMMakesMultipleTransforms() {
        let translate = DOM.Transform.translate(tx: 10, ty: 20)
        let scale = DOM.Transform.scale(sx: 10, sy: 20)
        let transform = LayerTree.Builder.createTransforms(from: [translate, scale])

        XCTAssertEqual(transform, [.translate(tx: 10, ty: 20),
                                   .scale(sx: 10, sy: 20)])
    }
}
