//
//  LayerTree.CSSCascadeTests.swift
//  SwiftDraw
//
//  Added by Misoservices for the Backdrop fork of SwiftDraw (altered source version).
//  Copyright 2026 Misoservices
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
import Testing
@testable import SwiftDraw

struct LayerTreeCSSCascadeTests {

    private struct NoChildLayer: Error {}

    private func makeLayer(_ body: String) throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """)
        return LayerTree.Builder(svg: svg).makeLayer()
    }

    private func commandStream(_ body: String) throws -> [RendererCommand<LayerTreeProvider.Types>] {
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: try makeLayer(body), colorConverter: .default)
    }

    // the layer of the first element drawn under the root <svg>
    private func firstChild(_ body: String) throws -> LayerTree.Layer {
        let root = try makeLayer(body)
        for case .layer(let l) in root.contents {
            return l
        }
        throw NoChildLayer()
    }

    private func fills(_ body: String) throws -> [LayerTree.Color] {
        try commandStream(body).compactMap {
            if case let .setFill(color: c) = $0 { return c }
            return nil
        }
    }

    private static let red = LayerTree.Color.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb)
    private static let blue = LayerTree.Color.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)

    @Test
    func transformFromStyleSheet() throws {
        let layer = try firstChild(#"<style>.t { transform: translate(10px, 20px) }</style><rect class="t" width="5" height="5"/>"#)
        #expect(layer.transform == [.translate(tx: 10, ty: 20)])
    }

    @Test
    func transformFromStyleAttribute() throws {
        let layer = try firstChild(#"<rect style="transform: rotate(90deg)" width="5" height="5"/>"#)
        #expect(layer.transform == [.rotate(radians: .pi / 2)])
    }

    @Test
    func styleSheetTransformOverridesAttribute() throws {
        let layer = try firstChild(#"<style>rect { transform: scale(2) }</style><rect transform="translate(5 5)" width="5" height="5"/>"#)
        #expect(layer.transform == [.scale(sx: 2, sy: 2)])
    }

    @Test
    func maskFromStyleSheet() throws {
        let layer = try firstChild("""
        <defs><mask id="m"><rect width="5" height="5" fill="white"/></mask></defs>
        <style>.masked { mask: url(#m) }</style>
        <rect class="masked" width="10" height="10"/>
        """)
        #expect(layer.mask != nil)
    }

    // clip-rule comes from the <clipPath> children (SD8), here through a descendant selector
    @Test
    func clipRuleFromStyleSheet() throws {
        let body = """
        <defs><clipPath id="c"><rect width="5" height="5"/></clipPath></defs>
        <style>#c rect { clip-rule: evenodd }</style>
        <rect id="r" clip-path="url(#c)" width="10" height="10"/>
        """
        let layer = try firstChild(body)
        #expect(layer.clipRule == .evenodd)
        #expect(try commandStream(body).contains {
            if case .setClip(path: _, rule: .evenodd) = $0 { return true }
            return false
        })
    }

    @Test
    func clipChildTransformFromStyleSheet() throws {
        let layer = try firstChild("""
        <defs><clipPath id="c"><rect class="moved" width="5" height="5"/></clipPath></defs>
        <style>.moved { transform: translate(3px, 4px) }</style>
        <rect clip-path="url(#c)" width="10" height="10"/>
        """)
        #expect(layer.clip.first?.transform == .init(a: 1, b: 0, c: 0, d: 1, tx: 3, ty: 4))
    }

    @Test
    func styleSheetFontSizeBeatsPresentationAttribute() throws {
        let root = try makeLayer(#"<style>text { font-size: 30px }</style><text font-size="10" x="0" y="20">Hi</text>"#)
        let sizes = root.contents.compactMap { contents -> LayerTree.Float? in
            if case let .text(_, _, att) = contents { return att.size }
            return nil
        }
        #expect(sizes == [30])
    }

    @Test
    func descendantSelectorFillsCommandStream() throws {
        let colors = try fills("""
        <style>g.icon > rect:first-child { fill: #ff0000 }</style>
        <g class="icon"><rect width="5" height="5"/><rect width="5" height="5"/></g>
        """)
        #expect(colors == [Self.red, .black])
    }

    @Test
    func oneBadDeclarationKeepsTheSheet() throws {
        let colors = try fills("""
        <style>:root { --c: red } .a { fill: var(--c); stroke: #00ff00 } .b { fill: #0000ff }</style>
        <rect class="a" width="5" height="5"/><rect class="b" width="5" height="5"/>
        """)
        #expect(colors == [.black, Self.blue])
    }

    @Test
    func useKeepsTheStyleOfItsOriginalElement() throws {
        let colors = try fills("""
        <style>defs > .a { fill: #ff0000 } use { fill: #0000ff }</style>
        <defs><rect id="r" class="a" width="5" height="5"/><circle id="c" r="2"/></defs>
        <use href="#r"/><use href="#c"/>
        """)
        // the referenced rect matches in <defs>; the circle inherits fill from the styled <use>
        #expect(colors == [Self.red, Self.blue])
    }

    @Test
    func rulesApplyInsideNestedSVG() throws {
        let colors = try fills("""
        <style>svg svg > rect { fill: #ff0000 }</style>
        <rect width="5" height="5"/>
        <svg x="10" width="10" height="10"><rect width="5" height="5"/></svg>
        """)
        #expect(colors == [.black, Self.red])
    }

    @Test
    func noneTransformOverridesLowerRule() throws {
        let root = try makeLayer(#"<style>rect { transform: scale(2) } #r { transform: none }</style><rect id="r" width="5" height="5"/>"#)
        // without a transform the rect is a plain shape, not a transformed layer
        #expect(root.contents.count == 1)
        guard case .shape = root.contents.first else {
            Issue.record("expected an untransformed shape, got \(root.contents)")
            return
        }
    }

    @Test
    func noneMaskOverridesLowerRule() throws {
        let root = try makeLayer("""
        <defs><mask id="m"><rect width="5" height="5" fill="white"/></mask></defs>
        <style>rect { mask: url(#m) } #r { mask: none }</style>
        <rect id="r" width="10" height="10"/>
        """)
        // without a mask the rect is a plain shape, not a masked layer
        #expect(root.contents.count == 1)
        guard case .shape = root.contents.first else {
            Issue.record("expected an unmasked shape, got \(root.contents)")
            return
        }
    }

    @Test
    func stylesheetStrokeWidthIsScaledForSFSymbols() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <style>g > line { stroke-width: 4 } line.b { stroke-width: 6 !important }</style>
        <g><line x1="0" y1="0" x2="10" y2="0" stroke="black"/><line class="b" x1="0" y1="0" x2="10" y2="0" stroke="black"/></g>
        </svg>
        """)
        StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5))
        let group = try #require(svg.childElements.first as? DOM.Group)
        #expect(DOM.presentationAttributes(for: group.childElements[0], styles: svg.styles).strokeWidth == 2)
        #expect(DOM.presentationAttributes(for: group.childElements[1], styles: svg.styles).strokeWidth == 3)
        #expect(svg.styles[0].rules[0].attributes.strokeWidth == 2)
    }

    @Test
    func complexSelectorStrokeWidthCountsForSFSymbols() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <style>g > line { stroke-width: 4 }</style>
        <g><line x1="0" y1="0" x2="10" y2="0" stroke="black"/></g>
        </svg>
        """)
        // the renderer warns "no effect" when this is 0
        #expect(StrokeWidthScaler.scale(svg, by: .init(multiplier: 0.5)) == 1)
    }
}
