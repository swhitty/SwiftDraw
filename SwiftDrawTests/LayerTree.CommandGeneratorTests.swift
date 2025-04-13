//
//  LayerTree.CommandGeneratorTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/12/18.
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

import XCTest
@testable import SwiftDraw

final class LayerTreeCommandGeneratorTests: XCTestCase {

    func testShapes() throws {
        let svg = try DOM.SVG.parse(fileNamed: "shapes.svg", in: .test)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(for: layer, colorConverter: .default)

        XCTAssertEqual(
            commands.count,
            165
        )
    }

    func testClip() {
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let circle = LayerTree.Shape.ellipse(within: .init(x: 0, y: 0, width: 10, height: 10))
        let rect = LayerTree.Shape.rect(within: .init(x: 20, y: 0, width: 10, height: 10), radii: .zero)

        let commands = generator.renderCommands(forClip: [circle, rect], using: nil)
        XCTAssertEqual(commands.count, 1)

        if case .setClip(path: let path, rule: let rule) = commands[0] {
            XCTAssertEqual(path, [circle, rect])
            XCTAssertEqual(rule, .nonzero)
        } else {
            XCTFail("expected clip command")
        }
    }

    func testTransforms() {
        let matrix = LayerTree.Transform.matrix(.init(a: 10, b: 20, c: 30, d: 40, tx: 50, ty: 60))
        let scale = LayerTree.Transform.scale(sx: 10, sy: 20)
        let translate = LayerTree.Transform.translate(tx: 10, ty: 20)
        let rotate = LayerTree.Transform.rotate(radians: 10)

        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        let commands = generator.renderCommands(forTransforms: [matrix, scale, translate, rotate])
        XCTAssertEqual(commands.count, 4)
    }
}

private extension LayerTree.CommandGenerator {

    func renderCommands(forClip shapes: [LayerTree.Shape], using rule: LayerTree.FillRule?) -> [RendererCommand<P.Types>] {
        renderCommands(forClip: shapes.map { LayerTree.ClipShape(shape: $0, transform: .identity) }, using: rule)
    }
}
