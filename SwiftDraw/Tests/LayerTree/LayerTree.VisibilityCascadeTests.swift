//
//  LayerTree.VisibilityCascadeTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
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


@testable import SwiftDraw
@testable import SwiftDrawDOM
import Testing

/// SD16: visibility follow-ups of SD7 (SVG 1.1 §11.6.2).
struct LayerTreeVisibilityCascadeTests {

    @Test
    func hiddenLeafWithFilterPaintsNothing() throws {
        let layer = try makeLayer("""
        <filter id="f"><feFlood flood-color="red"/></filter>
        <rect width="10" height="10" visibility="hidden" filter="url(#f)" opacity="0.5"/>
        """)
        #expect(findLayer(in: layer) { !$0.filters.isEmpty } == nil)
        #expect(allContents(of: layer).isEmpty)
    }

    @Test
    func visibleChildOfHiddenGroupStillPaints() throws {
        let layer = try makeLayer("""
        <g visibility="hidden"><rect width="10" height="10"/><rect width="5" height="5" visibility="visible"/></g>
        """)
        #expect(allContents(of: layer).count == 1)
    }

    @Test
    func rootWithDisplayNoneHasNoViewBoxTransform() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" style="display:none"><rect width="10" height="10"/></svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        #expect(layer.transform.isEmpty)
        #expect(layer.contents.isEmpty)
    }

    // MARK: helpers

    private func makeLayer(_ body: String) throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """)
        return LayerTree.Builder(svg: svg).makeLayer()
    }

    private func findLayer(in layer: LayerTree.Layer, where predicate: (LayerTree.Layer) -> Bool) -> LayerTree.Layer? {
        if predicate(layer) { return layer }
        for case let .layer(child) in layer.contents {
            if let found = findLayer(in: child, where: predicate) { return found }
        }
        return nil
    }

    private func allContents(of layer: LayerTree.Layer) -> [LayerTree.Layer.Contents] {
        layer.contents.flatMap { c -> [LayerTree.Layer.Contents] in
            if case let .layer(child) = c { return allContents(of: child) }
            return [c]
        }
    }
}
