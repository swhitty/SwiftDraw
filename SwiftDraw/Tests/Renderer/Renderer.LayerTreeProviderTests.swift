//
//  Renderer.LayerTreeProviderTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/11/18.
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
import Testing
@testable import SwiftDraw
import SwiftDrawDOM

struct RendererLayerTreeProviderTests {

    private typealias Point = LayerTree.Point
    private typealias Rect = LayerTree.Rect
    private typealias Size = LayerTree.Size
    private typealias Transform = LayerTree.Transform
    private typealias Matrix = LayerTree.Transform.Matrix

    @Test func float() {
        let float = LayerTreeProvider().createFloat(from: 10)
        #expect(float == 10)
    }

    @Test func point() {
        let point = LayerTreeProvider().createPoint(from: Point(10, 20))
        #expect(point == Point(10, 20))
    }

    @Test func size() {
        let size = LayerTreeProvider().createSize(from: Size(10, 20))
        #expect(size == Size(10, 20))
    }

    @Test func rect() {
        let rect = Rect(x: 0, y: 10, width: 20, height: 30)
        let converted = LayerTreeProvider().createRect(from: rect)
        #expect(converted == rect)
    }

    @Test func shape() {
        let shape = LayerTree.Shape.rect(
            within: Rect(x: 0, y: 10, width: 20, height: 30),
            radii: .zero
        )

        let converted = LayerTreeProvider().createPath(from: shape)
        #expect(converted == [shape])
    }

    @Test func subPaths() {
        let rect = LayerTree.Shape.rect(
            within: Rect(x: 0, y: 10, width: 20, height: 30),
            radii: .zero
        )
        let line = LayerTree.Shape.line(between: [.zero, Point(0, 100)])

        let p1 = LayerTreeProvider().createPath(from: rect)
        let p2 = LayerTreeProvider().createPath(from: line)
        let converted = LayerTreeProvider().createPath(from: [p1, p2])
        #expect(converted == [rect, line])
    }

    @Test func textPathIsUnsupported() {
        #expect(LayerTreeProvider().createPath(from: "", at: .zero, with: .normal) == nil)
    }

    @Test func color() {
        let color = LayerTreeProvider().createColor(from: .black)
        #expect(color == .black)
    }

    @Test func blendMode() {
        let blend = LayerTreeProvider().createBlendMode(from: .sourceIn)
        #expect(blend == .sourceIn)
    }

    @Test func transform() {
        let matrix = Transform.identity.toMatrix()
        let transform = LayerTreeProvider().createTransform(from: matrix)
        #expect(transform == .identity)
    }

    @Test func fillRule() {
        let fill = LayerTreeProvider().createFillRule(from: .nonzero)
        #expect(fill == .nonzero)
    }

    @Test func lineCap() {
        let cap = LayerTreeProvider().createLineCap(from: .butt)
        #expect(cap == .butt)
    }

    @Test func lineJoin() {
        let join = LayerTreeProvider().createLineJoin(from: .bevel)
        #expect(join == .bevel)
    }

    @Test func image() {
        let image = LayerTreeProvider().createImage(from: .mock)
        #expect(image == .mock)
    }
}

private extension LayerTree.Image {

    static var mock: LayerTree.Image {
        return .png(data: Data())
    }
}
