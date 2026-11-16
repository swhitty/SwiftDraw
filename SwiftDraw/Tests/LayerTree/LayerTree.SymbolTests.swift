//
//  LayerTree.SymbolTests.swift
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

struct LayerTreeSymbolTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """)
    }

    /// The layer a `<use>` builds for the symbol it references.
    private func symbolLayer(_ body: String) throws -> LayerTree.Layer {
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

    @Test(arguments: [
        #"<symbol id="s"><rect width="10" height="10"/></symbol>"#,
        #"<g><symbol id="s"><rect width="10" height="10"/></symbol></g>"#,
        #"<defs><symbol id="s"><rect width="10" height="10"/></symbol></defs>"#
    ])
    func symbolIsNotDrawnOnItsOwn(body: String) throws {
        let layer = LayerTree.Builder(svg: try parse(body)).makeLayer()
        #expect(shapes(in: layer).isEmpty)
    }

    @Test
    func symbolIsDrawnByUse() throws {
        let svg = try parse("""
        <symbol id="s"><rect width="10" height="10"/></symbol>
        <use href="#s"/>
        <use href="#s" x="20"/>
        """)
        #expect(shapes(in: LayerTree.Builder(svg: svg).makeLayer()).count == 2)
    }

    @Test
    func useEstablishesViewportForSymbol() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 24 24"><rect width="24" height="24"/></symbol>
        <use href="#s" x="10" y="20" width="48" height="96"/>
        """)
        // xMidYMid meet: scale 2, centred vertically in the 96 high viewport
        #expect(layer.transform == [.translate(tx: 10, ty: 44), .scale(sx: 2, sy: 2)])
        // the viewport in viewBox space, larger than the viewBox where meet letterboxes it
        #expect(clipRect(layer) == LayerTree.Rect(x: 0, y: -12, width: 24, height: 48))
    }

    @Test
    func viewBoxOriginAndPreserveAspectRatio() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="10 10 20 10" preserveAspectRatio="none"><rect width="10" height="10"/></symbol>
        <use href="#s" width="40" height="40"/>
        """)
        #expect(layer.transform == [.scale(sx: 2, sy: 4), .translate(tx: -10, ty: -10)])
        #expect(clipRect(layer) == LayerTree.Rect(x: 10, y: 10, width: 20, height: 10))
    }

    @Test
    func missingWidthAndHeightAreTheViewport() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 10 10"><rect width="10" height="10"/></symbol>
        <use href="#s"/>
        """)
        #expect(layer.transform == [.scale(sx: 10, sy: 10)])
    }

    @Test
    func overflowVisibleDoesNotClip() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 10 10" overflow="visible"><rect width="20" height="20"/></symbol>
        <use href="#s" width="10" height="10"/>
        """)
        #expect(layer.clip.isEmpty)
    }

    @Test
    func symbolWithoutViewBoxIsClippedUnscaled() throws {
        let layer = try symbolLayer("""
        <symbol id="s"><rect width="60" height="60"/></symbol>
        <use href="#s" x="5" y="5" width="40" height="30"/>
        """)
        #expect(layer.transform == [.translate(tx: 5, ty: 5)])
        #expect(clipRect(layer) == LayerTree.Rect(x: 0, y: 0, width: 40, height: 30))
    }

    @Test(arguments: [
        #"width="0" height="10""#,
        #"width="10" height="0""#,
        #"width="-10" height="10""#
    ])
    func emptyViewportDrawsNothing(size: String) throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 10 10"><rect width="10" height="10"/></symbol>
        <use href="#s" \(size)/>
        """)
        #expect(shapes(in: layer).isEmpty)
    }

    @Test
    func refXAndRefYPlaceThatPointAtXY() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 20 20" refX="10" refY="20"><rect width="20" height="20"/></symbol>
        <use href="#s" x="60" y="100" width="40" height="80"/>
        """)
        // the alignment of preserveAspectRatio no longer applies: (10, 20) lands on (60, 100)
        #expect(layer.transform == [.translate(tx: 60, ty: 100), .scale(sx: 2, sy: 2), .translate(tx: -10, ty: -20)])
        #expect(clipRect(layer) == LayerTree.Rect(x: 10, y: 20, width: 20, height: 40))
    }

    @Test
    func useStylesAreInherited() throws {
        let svg = try parse("""
        <symbol id="s" viewBox="0 0 10 10"><rect width="10" height="10"/></symbol>
        <use href="#s" fill="red"/>
        """)
        let fill = try #require(shapes(in: LayerTree.Builder(svg: svg).makeLayer()).first?.1)
        #expect(fill.fill == .color(.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb)))
    }

    @Test
    func symbolClipPathIsKeptInsideViewport() throws {
        let layer = try symbolLayer("""
        <clipPath id="c"><rect width="5" height="5"/></clipPath>
        <symbol id="s" viewBox="0 0 10 10" clip-path="url(#c)"><rect width="10" height="10"/></symbol>
        <use href="#s" width="20" height="20"/>
        """)
        #expect(layer.transform == [.scale(sx: 2, sy: 2)])
        #expect(clipRect(layer) == LayerTree.Rect(x: 0, y: 0, width: 10, height: 10))
        guard case .layer(let inner) = try #require(layer.contents.first) else {
            Issue.record("expected the symbol's own layer")
            return
        }
        #expect(clipRect(inner) == LayerTree.Rect(x: 0, y: 0, width: 5, height: 5))
    }

    @Test
    func referenceCycleThroughSymbolTerminates() throws {
        let svg = try parse("""
        <symbol id="s" viewBox="0 0 10 10">
          <rect width="10" height="10"/>
          <use href="#s" width="5" height="5"/>
        </symbol>
        <use href="#s" width="50" height="50"/>
        """)
        #expect(shapes(in: LayerTree.Builder(svg: svg).makeLayer()).count == 1)
    }

    @Test
    func boundingBoxOfUseOfSymbol() throws {
        let svg = try parse("""
        <symbol id="s" viewBox="0 0 10 10"><rect x="2" y="2" width="6" height="6"/></symbol>
        <use id="u" href="#s" x="10" y="10" width="20" height="20"/>
        <g id="g"><symbol id="t"><rect width="90" height="90"/></symbol><rect width="1" height="1"/></g>
        """)
        let builder = LayerTree.Builder(svg: svg)
        let use = try #require(svg.firstGraphicsElement(with: "u"))
        #expect(builder.makeBoundingBox(for: use) == LayerTree.Rect(x: 14, y: 14, width: 12, height: 12))
        // a symbol in a container adds nothing to its bounding box
        let group = try #require(svg.firstGraphicsElement(with: "g"))
        #expect(builder.makeBoundingBox(for: group) == LayerTree.Rect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test(arguments: [
        // the <use>'s size wins over the symbol's
        (##"<symbol id="s" viewBox="0 0 10 10" width="20" height="20"><rect width="10" height="10"/></symbol><use href="#s" width="40" height="40"/>"##, 4.0),
        // then the symbol's
        (##"<symbol id="s" viewBox="0 0 10 10" width="20" height="20"><rect width="10" height="10"/></symbol><use href="#s"/>"##, 2),
        // then 100% of the viewport
        (##"<symbol id="s" viewBox="0 0 10 10"><rect width="10" height="10"/></symbol><use href="#s"/>"##, 10),
        // each side on its own
        (##"<symbol id="s" viewBox="0 0 10 10" width="20" height="80"><rect width="10" height="10"/></symbol><use href="#s" height="40"/>"##, 2)
    ])
    func sizePrecedence(body: String, scale: Double) throws {
        let layer = try symbolLayer(body)
        let s = LayerTree.Float(scale)
        #expect(layer.transform.contains(.scale(sx: s, sy: s)))
    }

    @Test
    func symbolXAndYAddToUse() throws {
        let layer = try symbolLayer("""
        <symbol id="s" x="10" y="20" width="30" height="40"><rect width="60" height="60"/></symbol>
        <use href="#s" x="5" y="6"/>
        """)
        #expect(layer.transform == [.translate(tx: 15, ty: 26)])
        #expect(clipRect(layer) == LayerTree.Rect(x: 0, y: 0, width: 30, height: 40))
    }

    @Test
    func symbolSizeFitsViewBox() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 10 20" width="40" height="40" preserveAspectRatio="xMaxYMid meet"><rect width="10" height="20"/></symbol>
        <use href="#s"/>
        """)
        // scale 2, pushed to the right of the 40 wide viewport
        #expect(layer.transform == [.translate(tx: 20, ty: 0), .scale(sx: 2, sy: 2)])
        #expect(clipRect(layer) == LayerTree.Rect(x: -10, y: 0, width: 20, height: 20))
    }

    @Test
    func percentagesResolveAgainstTheViewportOfTheUse() throws {
        let layer = try symbolLayer("""
        <symbol id="s" viewBox="0 0 10 10" x="10%" width="50%" height="50%"><rect width="10" height="10"/></symbol>
        <use href="#s" y="20%"/>
        """)
        #expect(layer.transform == [.translate(tx: 10, ty: 20), .scale(sx: 5, sy: 5)])
    }

    @Test
    func percentageSizeOnUse() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 200 200">
          <symbol id="s" viewBox="0 0 10 10"><rect width="10" height="10"/></symbol>
          <svg width="100" height="50"><use href="#s" width="50%" height="50%"/></svg>
        </svg>
        """)
        let nested = try #require(svg.childElements.compactMap { $0 as? DOM.SVG }.first)
        let use = try #require(nested.childElements.first as? DOM.Use)
        guard case .layer(let layer) = try LayerTree.Builder(svg: svg).makeUseLayerContents(from: use, with: .init()) else {
            Issue.record("expected a layer")
            return
        }
        // 50% of the nested viewport (100 × 50): 50 × 25, meet scales by 2.5
        #expect(layer.transform == [.translate(tx: 12.5, ty: 0), .scale(sx: 2.5, sy: 2.5)])
    }

    @Test(arguments: [
        (#"overflow="hidden""#, true),
        (#"overflow="scroll""#, true),
        ("", true),
        (#"overflow="visible""#, false),
        (#"overflow="auto""#, false)
    ])
    func symbolSizeClipsToViewport(overflow: String, clips: Bool) throws {
        let layer = try symbolLayer("""
        <symbol id="s" width="20" height="30" \(overflow)><rect width="60" height="60"/></symbol>
        <use href="#s"/>
        """)
        #expect(clipRect(layer) == (clips ? LayerTree.Rect(x: 0, y: 0, width: 20, height: 30) : nil))
    }

    @Test
    func symbolTransformIsIgnored() throws {
        let layer = try symbolLayer("""
        <symbol id="s" transform="skewX(30)"><rect width="10" height="10"/></symbol>
        <use href="#s" x="5"/>
        """)
        #expect(layer.transform == [.translate(tx: 5, ty: 0)])
        #expect(layer.contents.count == 1)
    }

    @Test
    func symbolContentsResolvePercentagesAgainstUseSize() throws {
        let svg = try parse("""
        <symbol id="s"><rect width="100%" height="100%"/></symbol>
        <use href="#s" width="30" height="20"/>
        """)
        let (shape, _) = try #require(shapes(in: LayerTree.Builder(svg: svg).makeLayer()).first)
        #expect(shape == .rect(within: LayerTree.Rect(x: 0, y: 0, width: 30, height: 20), radii: .zero))
    }
}
