//
//  LayerTree.Builder.LayerTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/11/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import Foundation
import SwiftDrawDOM
@testable import SwiftDraw
import Testing

struct LayerTreeBuilderLayerTests {

    @Test
    func makeTextContentsFromDOM() {
        let text = DOM.Text(value: "Hello")
        let builder = LayerTree.Builder(svg: DOM.SVG(width: 10, height: 10))
        let contents = builder.makeTextContents(from: text, with: .init())

        guard case .text(let t, _, _)? = contents else {
            Issue.record("expected text contents")
            return
        }
        #expect(t == "Hello")
    }

    @Test
    func makeImageContentsFromDOM() throws {
        let image = DOM.Image(href: URL(maybeData: "data:image/png;base64,f00d")!)

        let contents = try LayerTree.Builder.makeImageContents(from: image)
        #expect(contents == .image(.png(data: Data(base64Encoded: "f00d")!)))

        let invalid = DOM.Image(href: URL(string: "aa")!)
        #expect(throws: (any Error).self) {
            try LayerTree.Builder.makeImageContents(from: invalid)
        }
    }

    @Test
    func makeUseContentsThrowsForMissingReference() {
        let builder = LayerTree.Builder(svg: DOM.SVG(width: 10, height: 10))
        let use = DOM.Use(href: URL(string: "#circle")!)
        #expect(throws: (any Error).self) {
            try builder.makeUseLayerContents(from: use, with: .init())
        }
    }

    @Test
    func makeUseContentsFromDOM() throws {
        let circle = DOM.Circle(cx: 5, cy: 5, r: 5)
        let svg = DOM.SVG(width: 10, height: 10)
        svg.defs.elements["circle"] = circle
        let builder = LayerTree.Builder(svg: svg)

        let use = DOM.Use(href: URL(string: "#circle")!)
        var contents = try builder.makeUseLayerContents(from: use, with: .init())
        guard case .layer(let l) = contents else {
            Issue.record("expected layer contents")
            return
        }
        #expect(l.contents.count == 1)
        #expect(l.transform == [])

        use.x = 10
        contents = try builder.makeUseLayerContents(from: use, with: .init())
        guard case .layer(let l1) = contents else {
            Issue.record("expected layer contents")
            return
        }
        #expect(l1.contents.count == 1)
        #expect(l1.transform == [.translate(tx: 10, ty: 0)])

        use.x = nil
        use.y = 20
        contents = try builder.makeUseLayerContents(from: use, with: .init())
        guard case .layer(let l2) = contents else {
            Issue.record("expected layer contents")
            return
        }
        #expect(l2.contents.count == 1)
        #expect(l2.transform == [.translate(tx: 0, ty: 20)])
    }
}

extension LayerTree.Image {

    static func png(data: Data) -> Self {
        Self(bitmap: .png(data))
    }

    static func jpeg(data: Data) -> Self {
        Self(bitmap: .jpeg(data))
    }
}
