//
//  LayerTree.RecursionTests.swift
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

import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

/// Recursive patterns, masks, markers and `<use>` (resvg test suite: paint-servers/pattern,
/// masking/mask, painting/marker and structure/use).
struct LayerTreeRecursionTests {

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="200" height="200">\(body)</svg>
                """
        )
    }

    /// Every element in the document with an id, including the contents of masks, patterns and markers.
    private func elements(in svg: DOM.SVG) -> [ObjectIdentifier: String] {
        var stack: [DOM.GraphicsElement] = svg.childElements
        stack += svg.defs.masks.flatMap(\.childElements)
        stack += svg.defs.patterns.flatMap(\.childElements)
        stack += svg.defs.markers.flatMap(\.childElements)
        stack += Array(svg.defs.elements.values)
        var ids = [ObjectIdentifier: String]()
        while let element = stack.popLast() {
            if let id = element.id { ids[ObjectIdentifier(element)] = id }
            if let container = element as? any ContainerElement { stack += container.childElements }
        }
        return ids
    }

    /// The dropped references as `id.property`, with `@n` when reached through n `<use>` elements.
    private func invalidReferences(_ body: String) throws -> [String] {
        let svg = try parse(body)
        let builder = LayerTree.Builder(svg: svg)
        let ids = elements(in: svg)
        return builder.invalidReferences.map {
            let id = ids[$0.element] ?? "?"
            return $0.instance.isEmpty ? "\(id).\($0.property)" : "\(id).\($0.property)@\($0.instance.count)"
        }.sorted()
    }

    // MARK: - references dropped

    static let recursive: [(name: String, body: String, invalid: [String])] = [
        (
            "pattern self-recursive",
            """
            <pattern id="p1" patternUnits="userSpaceOnUse" width="40" height="25">
              <rect id="r1" width="40" height="25" fill="url(#p1)" stroke="green"/>
            </pattern>
            <rect width="160" height="160" fill="url(#p1)"/>
            """, ["r1.fill"]
        ),
        (
            "pattern recursive on child drops only the reference closing the cycle",
            """
            <pattern id="p1" patternUnits="userSpaceOnUse" width="40" height="25">
              <rect id="r1" width="40" height="25" fill="url(#p2)"/>
            </pattern>
            <pattern id="p2" patternUnits="userSpaceOnUse" width="40" height="25">
              <rect id="r2" width="40" height="25" fill="url(#p1)"/>
            </pattern>
            """, ["r2.fill"]
        ),
        (
            "pattern stroke recursive through three patterns",
            """
            <pattern id="p1" width="1" height="1"><rect id="r1" width="1" height="1" stroke="url(#p2)"/></pattern>
            <pattern id="p2" width="1" height="1"><rect id="r2" width="1" height="1" stroke="url(#p3)"/></pattern>
            <pattern id="p3" width="1" height="1"><rect id="r3" width="1" height="1" stroke="url(#p1)"/></pattern>
            """, ["r3.stroke"]
        ),
        (
            "pattern recursive on an inherited fill",
            """
            <g fill="url(#p1)">
              <pattern id="p1" patternUnits="userSpaceOnUse" width="40" height="40">
                <rect id="r1" width="20" height="20" fill="green"/>
                <rect id="r2" x="22" y="22" width="16" height="16"/>
              </pattern>
            </g>
            """, ["r2.fill"]
        ),
        (
            "mask self-recursive",
            """
            <mask id="m1"><rect id="r1" width="160" height="160" fill="white" mask="url(#m1)"/></mask>
            """, ["r1.mask"]
        ),
        (
            "mask recursive through three masks",
            """
            <mask id="m1"><rect id="r1" width="1" height="1" mask="url(#m2)"/></mask>
            <mask id="m2"><rect id="r2" width="1" height="1" mask="url(#m3)"/></mask>
            <mask id="m3"><rect id="r3" width="1" height="1" mask="url(#m1)"/></mask>
            """, ["r3.mask"]
        ),
        (
            "marker recursive via mask, the mask first",
            """
            <mask id="m1"><path id="p1" d="M 40 140 L 160 140" stroke="white" marker-start="url(#k1)"/></mask>
            <marker id="k1"><rect id="r1" width="36" height="36" mask="url(#m1)"/></marker>
            """, ["r1.mask"]
        ),
        (
            "marker recursive via pattern, the marker first",
            """
            <marker id="k1"><rect id="r1" width="36" height="36" fill="url(#p1)"/></marker>
            <pattern id="p1" width="20" height="20"><path id="p2" d="M 2 10 L 18 10" marker-start="url(#k1)"/></pattern>
            """, ["p2.markerStart"]
        ),
        (
            "mask recursive on an inherited marker",
            """
            <g marker-start="url(#k1)">
              <mask id="m1"><path id="p1" d="M 40 160 L 160 160" stroke="white"/></mask>
            </g>
            <marker id="k1"><rect id="r1" width="36" height="36" mask="url(#m1)"/></marker>
            """, ["r1.mask"]
        ),
        (
            "each copy a use draws is checked on its own",
            """
            <marker id="k1"><use href="#p1"/></marker>
            <marker id="k2"><use href="#p1"/></marker>
            <path id="p1" d="M 1 1 5 3 1 5" marker-start="url(#k1)" marker-end="url(#k2)"/>
            """, ["p1.markerEnd@1", "p1.markerStart@1", "p1.markerStart@1"]
        ),
        (
            "nested definitions referencing their parent are not recursive",
            """
            <mask id="m1"><mask id="m2"><rect id="r1" width="200" height="200" mask="url(#m1)"/></mask></mask>
            <marker id="k1"><marker id="k2"><path id="p1" d="M 0 0 L 10 0" marker-start="url(#k1)"/></marker></marker>
            """, []
        ),
    ]

    @Test(arguments: recursive)
    func dropsRecursiveReferences(_ example: (name: String, body: String, invalid: [String])) throws {
        #expect(try invalidReferences(example.body) == example.invalid, "\(example.name)")
    }

    // MARK: - building

    /// The fills of the shapes in `layer` and its sublayers, in order.
    private func fills(in layer: LayerTree.Layer) -> [LayerTree.FillAttributes.Fill] {
        layer.contents.flatMap { contents -> [LayerTree.FillAttributes.Fill] in
            switch contents {
            case let .shape(_, _, fill): return [fill.fill]
            case let .layer(l): return fills(in: l)
            default: return []
            }
        }
    }

    private func fills(_ body: String) throws -> [LayerTree.FillAttributes.Fill] {
        fills(in: LayerTree.Builder(svg: try parse(body)).makeLayer())
    }

    @Test
    func recursiveUseOfAnAncestorDrawsNothing() throws {
        // structure/use/indirect-recursive-2: Chrome and resvg draw the rect once, not a copy through the use
        let body = """
            <g id="g1">
              <use id="u1" x="20" y="20" href="#g1"/>
              <rect width="10" height="10" fill="red"/>
            </g>
            """
        #expect(try fills(body).count == 1)
        let svg = try parse(body)
        let use = try #require(svg.firstGraphicsElement(with: "u1") as? DOM.Use)
        #expect(LayerTree.Builder(svg: svg).isRecursive(use))
    }

    @Test
    func useOfARecursiveUseIsNotRecursive() throws {
        let svg = try parse(
            """
            <g id="g1"><use id="u1" href="#g1"/><rect width="10" height="10"/></g>
            <use id="u2" href="#g1"/>
            """
        )
        let builder = LayerTree.Builder(svg: svg)
        let u1 = try #require(svg.firstGraphicsElement(with: "u1") as? DOM.Use)
        let u2 = try #require(svg.firstGraphicsElement(with: "u2") as? DOM.Use)
        #expect(builder.isRecursive(u1))
        #expect(!builder.isRecursive(u2))
    }

    @Test
    func selfRecursiveMaskIsIgnoredInsideItself() throws {
        // masking/mask/self-recursive: the rect inside the mask draws unmasked, so the mask is not empty
        let svg = try parse(
            """
            <mask id="m1"><rect id="r1" width="160" height="160" fill="white" mask="url(#m1)"/></mask>
            <rect id="r2" width="160" height="160" fill="green" mask="url(#m1)"/>
            """
        )
        let builder = LayerTree.Builder(svg: svg)
        let r2 = try #require(svg.firstGraphicsElement(with: "r2"))
        let mask = try #require(builder.createMaskLayer(for: r2))
        var masks = [LayerTree.Layer]()
        var stack = [mask]
        while let layer = stack.popLast() {
            if let inner = layer.mask { masks.append(inner) }
            stack += layer.contents.compactMap { if case let .layer(l) = $0 { return l } else { return nil } }
        }
        #expect(masks.isEmpty)
        #expect(fills(in: mask) == [.color(.rgba(r: 1, g: 1, b: 1, a: 1, space: .srgb))])
    }

    @Test
    func patternContentsInheritFromThePatternsAncestors() throws {
        let fills = try fills(
            """
            <g fill="blue">
              <pattern id="p1" patternUnits="userSpaceOnUse" width="10" height="10">
                <rect width="5" height="5"/>
              </pattern>
            </g>
            <rect width="20" height="20" fill="url(#p1)"/>
            """
        )
        guard case let .pattern(pattern) = fills.first else {
            Issue.record("expected a pattern fill")
            return
        }
        let contents = LayerTree.Layer()
        pattern.contents.forEach(contents.appendContents)
        #expect(self.fills(in: contents) == [.color(.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb))])
    }

    @Test
    func nestedDefinitionsAreFound() throws {
        let svg = try parse(
            """
            <pattern id="p1" width="1" height="1">
              <g fill="red"><pattern id="p2" width="1" height="1"/></g>
              <mask id="m1"><marker id="k1"/></mask>
            </pattern>
            """
        )
        #expect(svg.defs.patterns.map(\.id) == ["p1", "p2"])
        #expect(svg.defs.masks.map(\.id) == ["m1"])
        #expect(svg.defs.markers.map(\.id) == ["k1"])
        #expect(svg.defs.documentOrder == ["p1": 0, "p2": 1, "m1": 2, "k1": 3])
        // p2 inherits from <svg>, <pattern p1>, <g> and itself
        let p2 = try #require(svg.defs.patterns.last)
        #expect(p2.ancestors.count == 4)
        #expect(p2.ancestors[2].attributes.fill == .color(.keyword(.red)))
    }

    @Test
    func optimizerKeepsEqualAlphaInsideTransparencyLayer() {
        let commands: [RendererCommand<LayerTreeTypes>] = [
            .setAlpha(0.5),
            .pushTransparencyLayer,
            .setAlpha(0.5),
            .pushTransparencyLayer,
            .popTransparencyLayer,
            .popTransparencyLayer,
        ]
        let optimized = LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
        #expect(optimized.count == commands.count)
    }

    @Test
    func longMaskCycleIsBounded() throws {
        // 2,000 masks, each masking its contents with the next, and the last with the first
        let count = 2_000
        let masks = (0..<count).map {
            #"<mask id="m\#($0)"><rect id="r\#($0)" width="1" height="1" mask="url(#m\#(($0 + 1) % count))"/></mask>"#
        }.joined()
        let svg = try parse(masks + #"<rect width="1" height="1" mask="url(#m0)"/>"#)
        let builder = LayerTree.Builder(svg: svg)
        _ = builder.makeLayer()
        #expect(builder.invalidReferences.count == 1)
    }
}
