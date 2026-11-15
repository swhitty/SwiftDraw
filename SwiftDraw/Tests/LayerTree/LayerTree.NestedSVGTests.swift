//
//  LayerTree.NestedSVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
@testable import SwiftDraw
import Testing

struct LayerTreeNestedSVGTests {

    private func layer(_ body: String, attributes: String = "") throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" \(attributes)>\(body)</svg>
        """)
        return LayerTree.Builder(svg: svg).makeLayer()
    }

    private func shapes(in layer: LayerTree.Layer) -> [(LayerTree.StrokeAttributes, LayerTree.FillAttributes)] {
        layer.contents.flatMap { contents -> [(LayerTree.StrokeAttributes, LayerTree.FillAttributes)] in
            switch contents {
            case .layer(let child): shapes(in: child)
            case let .shape(_, stroke, fill): [(stroke, fill)]
            default: []
            }
        }
    }

    @Test(arguments: [
        #"<svg width="50" height="50"><rect width="10" height="10"/></svg>"#,
        #"<g><svg width="50" height="50" viewBox="0 0 10 10"><rect width="10" height="10"/></svg></g>"#,
        #"<svg width="50" height="50"><svg width="20" height="20"><rect width="10" height="10"/></svg></svg>"#
    ])
    func nestedSVGContentIsBuiltOnce(body: String) throws {
        #expect(try shapes(in: layer(body)).count == 1)
    }

    @Test
    func rootPresentationAttributesAreInheritedIntoNestedSVG() throws {
        let tree = try layer(
            #"<svg width="50" height="50"><rect width="10" height="10"/></svg>"#,
            attributes: #"fill="red" fill-opacity="0.5" stroke="blue" stroke-opacity="0.25" stroke-width="3""#
        )
        let (stroke, fill) = try #require(shapes(in: tree).first)
        #expect(fill.fill == .color(.rgba(r: 1, g: 0, b: 0, a: 0.5, space: .srgb)))
        #expect(stroke.color == .color(.rgba(r: 0, g: 0, b: 1, a: 0.25, space: .srgb)))
        #expect(stroke.width == 3)
    }
}
