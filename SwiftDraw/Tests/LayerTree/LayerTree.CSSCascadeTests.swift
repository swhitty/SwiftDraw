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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw
import Foundation

final class LayerTreeCSSCascadeTests: XCTestCase {

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

    func testTransformFromStyleSheet() throws {
        let layer = try firstChild(#"<style>.t { transform: translate(10px, 20px) }</style><rect class="t" width="5" height="5"/>"#)
        XCTAssertEqual(layer.transform, [.translate(tx: 10, ty: 20)])
    }

    func testTransformFromStyleAttribute() throws {
        let layer = try firstChild(#"<rect style="transform: rotate(90deg)" width="5" height="5"/>"#)
        XCTAssertEqual(layer.transform, [.rotate(radians: .pi / 2)])
    }

    func testStyleSheetTransformOverridesAttribute() throws {
        let layer = try firstChild(#"<style>rect { transform: scale(2) }</style><rect transform="translate(5 5)" width="5" height="5"/>"#)
        XCTAssertEqual(layer.transform, [.scale(sx: 2, sy: 2)])
    }

    func testMaskFromStyleSheet() throws {
        let layer = try firstChild("""
        <defs><mask id="m"><rect width="5" height="5" fill="white"/></mask></defs>
        <style>.masked { mask: url(#m) }</style>
        <rect class="masked" width="10" height="10"/>
        """)
        XCTAssertNotNil(layer.mask)
    }

    func testClipRuleFromStyleSheet() throws {
        let layer = try firstChild("""
        <defs><clipPath id="c"><rect width="5" height="5"/></clipPath></defs>
        <style>#r { clip-rule: evenodd }</style>
        <rect id="r" clip-path="url(#c)" width="10" height="10"/>
        """)
        XCTAssertEqual(layer.clipRule, .evenodd)
        XCTAssertTrue(try commandStream("""
        <defs><clipPath id="c"><rect width="5" height="5"/></clipPath></defs>
        <style>#r { clip-rule: evenodd }</style>
        <rect id="r" clip-path="url(#c)" width="10" height="10"/>
        """).contains {
            if case .setClip(path: _, rule: .evenodd) = $0 { return true }
            return false
        })
    }

    func testClipChildTransformFromStyleSheet() throws {
        let layer = try firstChild("""
        <defs><clipPath id="c"><rect class="moved" width="5" height="5"/></clipPath></defs>
        <style>.moved { transform: translate(3px, 4px) }</style>
        <rect clip-path="url(#c)" width="10" height="10"/>
        """)
        XCTAssertEqual(layer.clip.first?.transform, .init(a: 1, b: 0, c: 0, d: 1, tx: 3, ty: 4))
    }

    func testStyleSheetFontSizeBeatsPresentationAttribute() throws {
        let root = try makeLayer(#"<style>text { font-size: 30px }</style><text font-size="10" x="0" y="20">Hi</text>"#)
        let sizes = root.contents.compactMap { contents -> LayerTree.Float? in
            if case let .text(_, _, att) = contents { return att.size }
            return nil
        }
        XCTAssertEqual(sizes, [30])
    }

    func testDescendantSelectorFillsCommandStream() throws {
        let commands = try commandStream("""
        <style>g.icon > rect:first-child { fill: #ff0000 }</style>
        <g class="icon"><rect width="5" height="5"/><rect width="5" height="5"/></g>
        """)
        let fills = commands.compactMap { command -> LayerTree.Color? in
            if case let .setFill(color: c) = command { return c }
            return nil
        }
        XCTAssertEqual(fills, [.rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb), .black])
    }

    func testOneBadDeclarationKeepsTheSheet() throws {
        let commands = try commandStream("""
        <style>:root { --c: red } .a { fill: var(--c); stroke: #00ff00 } .b { fill: #0000ff }</style>
        <rect class="a" width="5" height="5"/><rect class="b" width="5" height="5"/>
        """)
        let fills = commands.compactMap { command -> LayerTree.Color? in
            if case let .setFill(color: c) = command { return c }
            return nil
        }
        XCTAssertEqual(fills, [.black, .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb)])
    }
}
