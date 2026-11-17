//
//  LayerTree.TextPositionListTests.swift
//  SwiftDraw
//
//  Copyright 2026 Simon Whitty
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

import SwiftDrawDOM
@testable import SwiftDraw
import Testing

/// SVG 1.1 §10.4: `x` and `y` on `<text>` are lists of lengths. The text starts at the first value;
/// the others position the following characters (see `LayerTreeTextCharacterTests`).
struct LayerTreeTextPositionListTests {

    private func parse(_ text: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">\(text)</svg>
        """)
    }

    private func textPoint(_ text: String) throws -> LayerTree.Point? {
        let layer = LayerTree.Builder(svg: try parse(text)).makeLayer()
        return points(in: layer).first
    }

    private func points(in layer: LayerTree.Layer) -> [LayerTree.Point] {
        layer.contents.flatMap { contents -> [LayerTree.Point] in
            switch contents {
            case .layer(let child): points(in: child)
            case let .text(_, point, _): [point]
            default: []
            }
        }
    }

    @Test(arguments: [
        #"<text x="50" y="100 134">Text</text>"#,
        #"<text x="50 60 70" y="100,134">Text</text>"#,
        #"<text x=" 50, 60 " y="100 , 134 ,150">Text</text>"#,
        #"<text x="50" y="100 134">Te<tspan fill="green">xt</tspan></text>"#,
        #"<text><tspan x="50 60" y="100 134">Text</tspan></text>"#,
    ])
    func textStartsAtTheFirstValue(text: String) throws {
        #expect(try textPoint(text) == LayerTree.Point(50, 100))
    }

    @Test
    func everyValueIsKeptInTheDOM() throws {
        let text = try #require(parse(#"<text x="1in 2" y="10%,20 30">Text</text>"#).childElements.first as? DOM.Text)
        #expect(text.xList == [96, 2])
        #expect(text.yList == [20, 20, 30])
        #expect(text.x == 96)
        #expect(text.y == 20)
    }

    @Test(arguments: ["100 abc", "100mmx", ",", ""])
    func anInvalidListIsIgnored(y: String) throws {
        let text = try #require(parse(#"<text x="50" y="\#(y)">Text</text>"#).childElements.first as? DOM.Text)
        #expect(text.y == nil)
        #expect(text.yList.isEmpty)
        #expect(text.x == 50)
    }
}
