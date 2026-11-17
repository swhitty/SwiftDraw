//
//  LayerTree.TransformTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 3/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct LayerTreeTransformTests {

    private typealias Transform = LayerTree.Transform
    private typealias Matrix = LayerTree.Transform.Matrix

    @Test
    func skewXMatrix() {
        let angle = LayerTree.Float.pi / 4
        let transform = Transform.skewX(angle: angle)
        #expect(transform.toMatrix() == Matrix(a: 1, b: 0, c: LayerTree.Float.tanf(angle), d: 1, tx: 0, ty: 0))
    }

    @Test
    func skewYMatrix() {
        let angle = LayerTree.Float.pi / 4
        let transform = Transform.skewY(angle: angle)
        #expect(transform.toMatrix() == Matrix(a: 1, b: LayerTree.Float.tanf(angle), c: 0, d: 1, tx: 0, ty: 0))
    }

    @Test
    func scaleMatrix() {
        let transform = Transform.scale(sx: 2.0, sy: 3.0)
        #expect(transform.toMatrix() == Matrix(a: 2.0, b: 0, c: 0, d: 3.0, tx: 0, ty: 0))
    }

    @Test
    func translateMatrix() {
        let transform = Transform.translate(tx: 2.0, ty: 3.0)
        #expect(transform.toMatrix() == Matrix(a: 1, b: 0, c: 0, d: 1, tx: 2.0, ty: 3.0))
    }

    @Test
    func rotateMatrix() {
        let angle = LayerTree.Float.pi / 4
        let transform = Transform.rotate(radians: angle)
        #expect(
            transform.toMatrix()
                == Matrix(
                    a: LayerTree.Float(cos(Double(angle))),
                    b: LayerTree.Float(sin(Double(angle))),
                    c: -LayerTree.Float(sin(Double(angle))),
                    d: LayerTree.Float(cos(Double(angle))),
                    tx: 0,
                    ty: 0
                )
        )
    }

    @Test
    func matrixConcatenation() {
        let concatenated = Transform.identity.toMatrix().concatenated(Transform.identity.toMatrix())
        #expect(concatenated == Transform.identity.toMatrix())
    }

    @Test
    func domMakesTranslateTransform() {
        let translate = DOM.Transform.translate(tx: 10, ty: 20)
        let transform = LayerTree.Builder.createTransform(for: translate)

        #expect(transform == [.translate(tx: 10, ty: 20)])
    }

    @Test
    func domMakesScaleTransform() {
        let scale = DOM.Transform.scale(sx: 10, sy: 20)
        let transform = LayerTree.Builder.createTransform(for: scale)

        #expect(transform == [.scale(sx: 10, sy: 20)])
    }

    @Test
    func domMakesRotateTransform() {
        let rotate = DOM.Transform.rotate(angle: 10)
        let transform = LayerTree.Builder.createTransform(for: rotate)

        let radians = 10 * Float.pi / 180.0
        #expect(transform == [.rotate(radians: radians)])
    }

    @Test
    func domMakesRotatePointTransform() {
        let rotate = DOM.Transform.rotatePoint(angle: 10, cx: 20, cy: 30)
        let transform = LayerTree.Builder.createTransform(for: rotate)

        let radians = 10 * Float.pi / 180.0
        #expect(
            transform == [
                .translate(tx: 20, ty: 30),
                .rotate(radians: radians),
                .translate(tx: -20, ty: -30),
            ]
        )
    }

    @Test
    func domMakesSkewXTransform() {
        let skew = DOM.Transform.skewX(angle: 10)
        let transform = LayerTree.Builder.createTransform(for: skew)

        let radians = 10 * Float.pi / 180.0
        #expect(transform == [.skewX(angle: radians)])
    }

    @Test
    func domMakesSkewYTransform() {
        let skew = DOM.Transform.skewY(angle: 10)
        let transform = LayerTree.Builder.createTransform(for: skew)

        let radians = 10 * Float.pi / 180.0
        #expect(transform == [.skewY(angle: radians)])
    }

    @Test
    func domMakesMatrixTransform() {
        let matrix = DOM.Transform.matrix(a: 10, b: 20, c: 30, d: 40, e: 50, f: 60)
        let transform = LayerTree.Builder.createTransform(for: matrix)

        let expected = Matrix(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60)
        #expect(transform == [.matrix(expected)])
    }

    @Test
    func domMakesMultipleTransforms() {
        let translate = DOM.Transform.translate(tx: 10, ty: 20)
        let scale = DOM.Transform.scale(sx: 10, sy: 20)
        let transform = LayerTree.Builder.createTransforms(from: [translate, scale])

        #expect(
            transform == [
                .translate(tx: 10, ty: 20),
                .scale(sx: 10, sy: 20),
            ]
        )
    }
}
