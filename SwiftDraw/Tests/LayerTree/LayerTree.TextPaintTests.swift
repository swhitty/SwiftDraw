//
//  LayerTree.TextPaintTests.swift
//  SwiftDraw
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
import SwiftDrawDOM
import Foundation
import Testing

/// Text filled with a gradient or pattern, or stroked, is drawn as glyph outlines through the shape pipeline.
struct LayerTreeTextPaintTests {

    static let defs = """
    <linearGradient id="lg"><stop offset="0" stop-color="white" /><stop offset="1" stop-color="black" /></linearGradient>
    <radialGradient id="rg"><stop offset="0" stop-color="white" /><stop offset="1" stop-color="black" /></radialGradient>
    <pattern id="pt" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="2" height="2" fill="green" /></pattern>
    """

    @Test
    func solidFillStaysText() throws {
        let contents = try makeContents(#"fill="red""#)
        guard case .text(_, _, let attributes) = contents else {
            Issue.record("expected text, got \(contents)")
            return
        }
        #expect(attributes.color == .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb))
    }

    @Test
    func invalidPaintServerUsesFallbackColor() throws {
        let contents = try makeContents(#"fill="url(#missing) red""#)
        guard case .text(_, _, let attributes) = contents else {
            Issue.record("expected text, got \(contents)")
            return
        }
        #expect(attributes.color == .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb))
    }

    @Test
    func clipPathTextIgnoresStrokeAndPaintServers() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <defs>\(Self.defs)<clipPath id="c"><text x="10" y="50" fill="url(#lg)" stroke="red">Text</text></clipPath></defs>
            <rect width="100" height="100" clip-path="url(#c)" />
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let masks = layer.allLayers.compactMap(\.mask).flatMap(\.allContents)
        // the clip is the white text itself, never painted outlines
        #expect(masks.contains { if case .text(_, _, let a) = $0 { return a.color == .white }; return false })
        #expect(!masks.contains { if case .shape = $0 { return true }; return false })
    }

#if canImport(CoreText)
    @Test(arguments: [
        ("url(#lg)", "linear"),
        ("url(#rg)", "radial"),
        ("url(#pt)", "pattern"),
        ("url(#lg) red", "linear")
    ])
    func paintServerFillIsOutlined(_ fill: String, _ kind: String) throws {
        let contents = try makeContents(#"fill="\#(fill)" fill-opacity="0.5""#)
        guard case .shape(.path(let path), let stroke, let fillAttributes) = contents else {
            Issue.record("expected outlines, got \(contents)")
            return
        }
        #expect(!path.segments.isEmpty)
        #expect(stroke.color == .none)
        #expect(fillAttributes.opacity == 0.5)
        #expect(fillAttributes.rule == .nonzero)
        switch (fillAttributes.fill, kind) {
        case (.linearGradient, "linear"), (.radialGradient, "radial"), (.pattern, "pattern"):
            ()
        default:
            Issue.record("expected \(kind), got \(fillAttributes.fill)")
        }
    }

    @Test
    func strokedTextIsOutlined() throws {
        let contents = try makeContents(#"fill="none" stroke="green" stroke-width="3" stroke-opacity="0.5" stroke-dasharray="2 1" stroke-linejoin="round""#)
        guard case .shape(.path, let stroke, let fill) = contents else {
            Issue.record("expected outlines, got \(contents)")
            return
        }
        #expect(fill.fill == .color(.none))
        #expect(stroke.color == .color(LayerTree.Color(0, 128, 0).withAlpha(0.5)))
        #expect(stroke.width == 3)
        #expect(stroke.join == .round)
        #expect(stroke.dashArray == [2, 1])
    }

    @Test(arguments: ["url(#lg)", "url(#rg)", "url(#pt)"])
    func paintServerStrokeIsOutlined(_ stroke: String) throws {
        let contents = try makeContents(#"fill="none" stroke="\#(stroke)" stroke-width="4" stroke-opacity="0.25""#)
        guard case .shape(.path, let strokeAttributes, _) = contents else {
            Issue.record("expected outlines, got \(contents)")
            return
        }
        #expect(strokeAttributes.opacity == 0.25)
        #expect(strokeAttributes.color != .none)
    }

    @Test
    func zeroWidthOrTransparentStrokeStaysText() throws {
        for attributes in [#"stroke="red" stroke-width="0""#, #"stroke="red" stroke-opacity="0""#, #"stroke="none""#] {
            let contents = try makeContents(attributes)
            guard case .text = contents else {
                Issue.record("expected text for \(attributes), got \(contents)")
                continue
            }
        }
    }

    @Test
    func outlinedTextIsPaintedWithTheGradient() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <defs>\(Self.defs)</defs>
            <text x="10" y="50" font-size="40" fill="url(#lg)" stroke="black">Text</text>
        </svg>
        """)
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(100, 100), options: .default)
        let commands = generator.renderCommands(for: LayerTree.Builder(svg: svg).makeLayer(), colorConverter: .default)
        let gradient = try #require(commands.firstIndex { if case .drawLinearGradient = $0 { return true }; return false })
        let stroke = try #require(commands.firstIndex { if case .stroke = $0 { return true }; return false })
        // fill, then stroke
        #expect(gradient < stroke)
    }
#endif

    func makeContents(_ attributes: String) throws -> LayerTree.Layer.Contents {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
            <defs>\(Self.defs)</defs>
            <text x="10" y="50" font-size="40" \(attributes)>Text</text>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        return try #require(layer.allContents.first)
    }
}

private extension LayerTree.Layer {

    /// The contents of this layer and its sublayers, depth first, excluding the sublayers themselves.
    var allContents: [Contents] {
        contents.flatMap { contents -> [Contents] in
            if case .layer(let l) = contents { return l.allContents }
            return [contents]
        }
    }

    /// This layer, its sublayers and their masks.
    var allLayers: [LayerTree.Layer] {
        [self] + (mask?.allLayers ?? []) + contents.flatMap { contents -> [LayerTree.Layer] in
            if case .layer(let l) = contents { return l.allLayers }
            return []
        }
    }
}
