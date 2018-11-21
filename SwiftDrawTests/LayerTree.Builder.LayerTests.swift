//
//  LayerTree.Builder.LayerTests.swift
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

final class LayerTreeBuilderLayerTests: XCTestCase {

    func testMakeTextContentsFromDOM() {
        let text = DOM.Text(value: "Hello")
        let contents = LayerTree.Builder.makeTextContents(from: text, with: .init())
        
        guard case .text(let t) = contents else { XCTFail(); return }
        XCTAssertEqual(t.0, "Hello")
    }

    func testMakeImageContentsFromDOM() throws {
        let image = DOM.Image(href: URL(maybeData: "data:image/png;base64,f00d")!,
                              width: 50,
                              height: 50)

        let contents = try LayerTree.Builder.makeImageContents(from: image)
        XCTAssertEqual(contents, .image(.png(data: Data(base64Encoded: "f00d")!)))

        let invalid = DOM.Image(href: URL(string: "aa")!, width: 10, height: 20)
        XCTAssertThrowsError(try LayerTree.Builder.makeImageContents(from: invalid))
    }

    func testMakeLayerFromDOM() {
        let circle = DOM.Circle(cx: 5, cy: 5, r: 5)
        let svg = DOM.SVG(width: 10, height: 10)
        svg.defs.elements["circle"] = circle
        let builder = LayerTree.Builder(svg: svg)

        let use = DOM.Use(href: URL(string: "#circle")!)
        let contents = builder.makeUseLayerContents(from: use, with: .init())!

        guard case .layer(let l) = contents else { XCTFail(); return }
        XCTAssertEqual(l.contents.count, 1)
    }
}
