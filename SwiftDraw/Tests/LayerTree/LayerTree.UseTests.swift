//
//  LayerTree.UseTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

@testable import SwiftDrawDOM
@testable import SwiftDraw
import Foundation
import Testing

struct LayerTreeUseTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">\(body)</svg>
        """)
    }

    /// The layer the first top-level `<use>` builds for what it references.
    private func useLayer(_ body: String) throws -> LayerTree.Layer {
        let svg = try parse(body)
        let use = try #require(svg.childElements.compactMap { $0 as? DOM.Use }.first)
        let builder = LayerTree.Builder(svg: svg)
        guard case .layer(let layer) = try builder.makeUseLayerContents(from: use, with: .init()) else {
            Issue.record("expected a layer")
            return LayerTree.Layer()
        }
        return layer
    }

    private func shapes(in layer: LayerTree.Layer) -> [(LayerTree.Shape, LayerTree.FillAttributes)] {
        layer.contents.flatMap { contents -> [(LayerTree.Shape, LayerTree.FillAttributes)] in
            switch contents {
            case .layer(let child): shapes(in: child)
            case let .shape(shape, _, fill): [(shape, fill)]
            default: []
            }
        }
    }

    private func clipRect(_ layer: LayerTree.Layer) -> LayerTree.Rect? {
        guard layer.clip.count == 1, case let .rect(within: rect, radii: _) = layer.clip[0].shape else { return nil }
        return rect
    }

    // MARK: - <use> → <svg>

    @Test(arguments: [
        // the <use>'s width and height replace the <svg>'s
        (#"<svg id="s" x="40" y="40" width="80" height="80"/>"#, #"width="100" height="150""#,
         [.translate(tx: 40, ty: 40)], LayerTree.Rect(x: 0, y: 0, width: 100, height: 150)),
        // only the width
        (#"<svg id="s" x="40" y="40" width="80" height="80"/>"#, #"width="100""#,
         [.translate(tx: 40, ty: 40)], LayerTree.Rect(x: 0, y: 0, width: 100, height: 80)),
        // without its own size the <svg> is 100%, unless the <use> sizes it
        (#"<svg id="s"/>"#, #"width="100" height="150""#,
         [], LayerTree.Rect(x: 0, y: 0, width: 100, height: 150)),
        (#"<svg id="s"/>"#, "",
         [], LayerTree.Rect(x: 0, y: 0, width: 200, height: 200)),
        // the viewBox maps into the <use>'s size: xMidYMid meet, scale ½, centred vertically
        (#"<svg id="s" viewBox="0 0 200 200"/>"#, #"width="100" height="150""#,
         [.translate(tx: 0, ty: 25), .scale(sx: 0.5, sy: 0.5)], LayerTree.Rect(x: 0, y: -50, width: 200, height: 300)),
        // the <use>'s x and y offset the <svg>'s own
        (#"<svg id="s" x="5" y="5" width="80" height="80"/>"#, #"x="10" y="20""#,
         [.translate(tx: 10, ty: 20), .translate(tx: 5, ty: 5)], LayerTree.Rect(x: 0, y: 0, width: 80, height: 80))
    ] as [(String, String, [LayerTree.Transform], LayerTree.Rect)])
    func useEstablishesViewportForSVG(svg: String, attributes: String,
                                      transform: [LayerTree.Transform], clip: LayerTree.Rect) throws {
        let layer = try useLayer("""
        <defs>\(svg.replacingOccurrences(of: "/>", with: #"><rect width="10" height="10"/></svg>"#))</defs>
        <use href="#s" \(attributes)/>
        """)
        #expect(layer.transform == transform)
        #expect(clipRect(layer) == clip)
        #expect(shapes(in: layer).count == 1)
    }

    @Test
    func sizeOfOuterUseDoesNotReachSVG() throws {
        let layer = try useLayer("""
        <defs>
          <svg id="s" x="40" y="40" width="80" height="80"><rect width="10" height="10"/></svg>
          <use id="u" href="#s" height="100"/>
        </defs>
        <use href="#u" width="200"/>
        """)
        let inner = try #require(layer.contents.compactMap {
            if case .layer(let l) = $0 { return l } else { return nil }
        }.first(where: { !$0.clip.isEmpty }))
        #expect(clipRect(inner) == LayerTree.Rect(x: 0, y: 0, width: 80, height: 100))
    }

    @Test(arguments: [#"width="0""#, #"height="0""#] as [String])
    func zeroSizeDisablesSVG(attributes: String) throws {
        let layer = try useLayer("""
        <defs><svg id="s" width="80" height="80"><rect width="10" height="10"/></svg></defs>
        <use href="#s" \(attributes)/>
        """)
        #expect(shapes(in: layer).isEmpty)
    }

    // MARK: - referenced elements

    @Test
    func instanceInheritsFromUseNotFromOriginalAncestors() throws {
        let svg = try parse("""
        <defs><g fill="red" transform="scale(4)"><rect id="r" width="10" height="10"/></g></defs>
        <use href="#r" fill="lime"/>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let fill = try #require(shapes(in: layer).first?.1)
        #expect(fill.fill == .color(.rgba(r: 0, g: 1, b: 0, a: 1, space: .srgb)))
        // the transform of the original parent does not apply either
        #expect(try useLayer(##"<defs><g transform="scale(4)"><rect id="r" width="10" height="10"/></g></defs><use href="#r"/>"##)
            .transform.isEmpty)
    }

    @Test
    func duplicateIDsDrawTheFirst() throws {
        let layer = try useLayer("""
        <defs><rect id="r" width="1" height="1"/><rect id="r" width="2" height="2"/></defs>
        <use href="#r"/>
        """)
        let shape = try #require(shapes(in: layer).first?.0)
        #expect(shape == .rect(within: LayerTree.Rect(x: 0, y: 0, width: 1, height: 1), radii: .zero))
    }

    @Test(arguments: [
        #"<random><rect id="r" width="10" height="10"/></random>"#,
        #"<clipPath id="c"><g><rect id="r" width="10" height="10"/></g></clipPath>"#
    ] as [String])
    func drawsChildOfUnrenderedElement(body: String) throws {
        let layer = try useLayer(##"<use href="#r"/>"## + body)
        #expect(shapes(in: layer).count == 1)
    }
}
