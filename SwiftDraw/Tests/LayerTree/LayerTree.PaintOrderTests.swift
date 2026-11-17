//
//  LayerTree.PaintOrderTests.swift
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

struct LayerTreePaintOrderTests {

    private static let marker = """
    <marker id="m" markerWidth="4" markerHeight="4" refX="2" refY="2" markerUnits="userSpaceOnUse">
      <rect width="4" height="4" fill="blue" stroke="yellow"/>
    </marker>
    """

    private func layer(_ body: String) throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(Self.marker)\(body)</svg>
        """)
        return LayerTree.Builder(svg: svg).makeLayer()
    }

    private func commands(_ body: String) throws -> [RendererCommand<LayerTreeProvider.Types>] {
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: try layer(body), colorConverter: .default)
    }

    private static let names: [LayerTree.Color: String] = [
        .rgba(r: 1, g: 0, b: 0, a: 1, space: .srgb): "red",
        .rgba(r: 0, g: 1, b: 0, a: 1, space: .srgb): "lime",
        .rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb): "blue",
        .rgba(r: 1, g: 1, b: 0, a: 1, space: .srgb): "yellow"
    ]

    private func name(_ color: LayerTree.Color) -> String {
        Self.names[color, default: "\(color)"]
    }

    /// Each fill and stroke as `fill:<colour>` or `stroke:<colour>`, and `[` `]` for transparency layers.
    private func paints(_ body: String) throws -> [String] {
        var fill = "", stroke = ""
        var result = [String]()
        for command in try commands(body) {
            switch command {
            case .setFill(let color): fill = name(color)
            case .setStroke(let color): stroke = name(color)
            case .fill: result.append("fill:\(fill)")
            case .stroke: result.append("stroke:\(stroke)")
            case .pushTransparencyLayer: result.append("[")
            case .popTransparencyLayer: result.append("]")
            default: ()
            }
        }
        return result
    }

    private static let shape = #"d="M 10 10 H 50 V 50" fill="red" stroke="lime" marker-end="url(#m)""#

    @Test(arguments: [
        ("", ["fill:red", "stroke:lime", "marker"]),
        (#"paint-order="normal""#, ["fill:red", "stroke:lime", "marker"]),
        (#"paint-order="stroke""#, ["stroke:lime", "fill:red", "marker"]),
        (#"paint-order="markers""#, ["marker", "fill:red", "stroke:lime"]),
        (#"paint-order="markers stroke""#, ["marker", "stroke:lime", "fill:red"]),
        (#"paint-order="stroke markers""#, ["stroke:lime", "marker", "fill:red"]),
        (#"paint-order="stroke markers fill""#, ["stroke:lime", "marker", "fill:red"]),
        (#"paint-order="fill markers stroke""#, ["fill:red", "marker", "stroke:lime"]),
        (#"style="paint-order: stroke""#, ["stroke:lime", "fill:red", "marker"]),
        (#"paint-order="stroke stroke""#, ["fill:red", "stroke:lime", "marker"])
    ] as [(String, [String])])
    func paintsInOrder(attribute: String, expected: [String]) throws {
        // the marker's own rect always draws its fill then its stroke
        let marker = ["fill:blue", "stroke:yellow"]
        let expected = expected.flatMap { $0 == "marker" ? marker : [$0] }
        #expect(try paints("<path \(Self.shape) \(attribute)/>") == expected)
    }

    @Test
    func isInherited() throws {
        #expect(try paints(#"<g paint-order="stroke"><path \#(Self.shape)/></g>"#) ==
                ["stroke:lime", "fill:red", "fill:blue", "stroke:yellow"])
        // an invalid value is dropped, so the inherited order applies
        #expect(try paints(#"<g paint-order="stroke"><path \#(Self.shape) paint-order="fill fill"/></g>"#) ==
                ["stroke:lime", "fill:red", "fill:blue", "stroke:yellow"])
    }

    @Test
    func markerContentsDoNotInheritFromTheShape() throws {
        // the shape's order does not reach the marker's rect, which inherits from <marker>
        #expect(try paints(#"<path \#(Self.shape) paint-order="stroke"/>"#).suffix(2) == ["fill:blue", "stroke:yellow"])
    }

    @Test(arguments: ["", #"paint-order="normal""#, #"paint-order="fill""#, #"paint-order="fill stroke markers""#])
    func defaultOrderBuildsTheSameTree(attribute: String) throws {
        #expect(try layer("<path \(Self.shape) \(attribute)/>") == layer("<path \(Self.shape)/>"))
        #expect(try layer(#"<rect width="10" height="10" fill="red" stroke="lime" \#(attribute)/>"#) ==
                layer(#"<rect width="10" height="10" fill="red" stroke="lime"/>"#))
    }

    @Test
    func shapeWithoutMarkersOrStrokeIsNotSplit() throws {
        let plain = try layer(#"<rect width="10" height="10" fill="red"/>"#)
        #expect(try layer(#"<rect width="10" height="10" fill="red" paint-order="stroke"/>"#) == plain)
        #expect(try layer(#"<rect width="10" height="10" fill="red" paint-order="markers stroke"/>"#) == plain)
    }

    @Test
    func opacityAppliesOnceToTheGroup() throws {
        let paints = try paints(#"<path \#(Self.shape) paint-order="stroke" opacity="0.5"/>"#)
        #expect(paints == ["[", "stroke:lime", "fill:red", "fill:blue", "stroke:yellow", "]"])
    }

    @Test
    func opacityClipMaskAndFilterStayOnTheElementLayer() throws {
        let root = try layer("""
        <clipPath id="c"><rect width="50" height="50"/></clipPath>
        <mask id="k"><rect width="100" height="100" fill="white"/></mask>
        <filter id="f"><feGaussianBlur stdDeviation="1"/></filter>
        <path \(Self.shape) paint-order="stroke" opacity="0.5" clip-path="url(#c)" mask="url(#k)" filter="url(#f)"/>
        """)
        let element = try #require(root.contents.compactMap { content -> LayerTree.Layer? in
            if case let .layer(l) = content, l.opacity == 0.5 { return l } else { return nil }
        }.first)
        #expect(!element.clip.isEmpty)
        #expect(element.mask != nil)
        #expect(!element.filters.isEmpty)

        // the stroke, fill and marker are one group inside it, with nothing of their own
        #expect(element.contents.count == 1)
        let group = try #require(element.contents.first.flatMap { content -> LayerTree.Layer? in
            if case let .layer(l) = content { return l } else { return nil }
        })
        #expect(group.isPaintOrdered)
        #expect(group.opacity == 1 && group.clip.isEmpty && group.mask == nil && group.filters.isEmpty)
        #expect(group.contents.count == 3)
    }

    @Test(arguments: ["stroke", "markers stroke", "stroke markers"])
    func sfSymbolPathsIgnoreTheOrder(order: String) throws {
        func paths(_ attribute: String) throws -> [LayerTree.Path] {
            let root = try layer(#"<path d="M 10 10 H 50 V 50 Z" stroke="lime" marker-end="url(#m)" \#(attribute)/>"#)
            return SFSymbolRenderer.getSymbolPaths(for: root).map(\.path)
        }
        let expected = try paths(#"fill="red""#)
        #expect(try paths(#"fill="red" paint-order="\#(order)""#) == expected)
        // a symbol layer keeps the shape's path even without fill (preserve), as in the default order
        let symbol = #"class="monochrome-0" fill="none""#
        #expect(try paths("\(symbol) paint-order=\"\(order)\"") == paths(symbol))
    }
}
