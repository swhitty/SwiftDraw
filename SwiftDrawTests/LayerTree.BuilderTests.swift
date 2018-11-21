//
//  LayerTree.BuilderTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright © 2018 WhileLoop Pty Ltd. All rights reserved.
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

final class LayerTreeBuilderTests: XCTestCase {

    func testMakeViewBoxTransform() {
        var transform = LayerTree.Builder.makeTransform(for: nil, width: 100, height: 200)
        XCTAssertEqual(transform, [])

        let viewbox = DOM.SVG.ViewBox(x: 0, y: 0, width: 200, height: 200)
        transform = LayerTree.Builder.makeTransform(for: viewbox, width: 100, height: 100)
        XCTAssertEqual(transform, [.scale(sx: 0.5, sy: 0.5)])

        let viewbox1 = DOM.SVG.ViewBox(x: 10, y: -10, width: 100, height: 100)
        transform = LayerTree.Builder.makeTransform(for: viewbox1, width: 100, height: 100)
        XCTAssertEqual(transform, [.translate(tx: -10, ty: 10)])
    }

    func testDOMMaskMakesLayer() {
        let circle = DOM.Circle(cx: 5, cy: 5, r: 5)
        let line = DOM.Line(x1: 0, y1: 0, x2: 10, y2: 0)
        let svg = DOM.SVG(width: 10, height: 10)
        svg.defs.masks.append(DOM.Mask(id: "mask1", childElements: [circle, line]))

        let builder = LayerTree.Builder(svg: svg)

        let element = DOM.GraphicsElement()
        element.mask = URL(string: "#mask1")

        let layer = builder.createMaskLayer(for: element)

        XCTAssertEqual(layer?.contents.count, 2)
    }
}
