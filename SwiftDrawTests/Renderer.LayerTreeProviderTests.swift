//
//  Renderer.LayerTreeProviderTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/11/18.
//  Copyright © 2018 WhileLoop Pty Ltd. All rights reserved.
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

final class RendererLayerTreeProviderTests: XCTestCase {

    private typealias Point = LayerTree.Point
    private typealias Rect = LayerTree.Rect
    private typealias Size = LayerTree.Size
    private typealias Transform = LayerTree.Transform
    private typealias Matrix = LayerTree.Transform.Matrix

    func testFloat() {
        let float = LayerTreeProvider().createFloat(from: 10)
        XCTAssertEqual(float, 10)
    }

    func testPoint() {
        let point = LayerTreeProvider().createPoint(from: Point(10, 20))
        XCTAssertEqual(point, Point(10, 20))
    }

    func testSize() {
        let size = LayerTreeProvider().createSize(from: Size(10, 20))
        XCTAssertEqual(size, Size(10, 20))
    }

    func testRect() {
        let rect = Rect(x: 0, y: 10, width: 20, height: 30)
        let converted = LayerTreeProvider().createRect(from: rect)
        XCTAssertEqual(converted, rect)
    }

    func testShape() {
        let shape = LayerTree.Shape.rect(within: Rect(x: 0, y: 10, width: 20, height: 30),
                                         radii: .zero)

        let converted = LayerTreeProvider().createPath(from: shape)
        XCTAssertEqual(converted, shape)
    }

    func testColor() {
        let color = LayerTreeProvider().createColor(from: .black)
        XCTAssertEqual(color, .black)
    }

    func testBlendMode() {
        let blend = LayerTreeProvider().createBlendMode(from: .sourceIn)
        XCTAssertEqual(blend, .sourceIn)
    }

    func testTransform() {
        let matrix = Transform.identity.toMatrix()
        let transfrom = LayerTreeProvider().createTransform(from: matrix)
        XCTAssertEqual(transfrom, .identity)
    }

    func testFillRule() {
        let fill = LayerTreeProvider().createFillRule(from: .nonzero)
        XCTAssertEqual(fill, .nonzero)
    }

    func testLineCap() {
        let cap = LayerTreeProvider().createLineCap(from: .butt)
        XCTAssertEqual(cap, .butt)
    }

    func testLineJoin() {
        let join = LayerTreeProvider().createLineJoin(from: .bevel)
        XCTAssertEqual(join, .bevel)
    }

    func testImage() {
        let image = LayerTreeProvider().createImage(from: .mock)
        XCTAssertEqual(image, .mock)
    }
}

private extension LayerTree.Image {

    static var mock: LayerTree.Image {
        return .png(data: Data())
    }
}

