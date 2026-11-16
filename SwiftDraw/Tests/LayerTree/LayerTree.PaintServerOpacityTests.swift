//
//  LayerTree.PaintServerOpacityTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/11/26.
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
import SwiftDrawDOM
import Foundation
import Testing

/// fill-opacity and stroke-opacity on gradient and pattern paint, pattern strokes, and the fallback
/// colour for objectBoundingBox paint servers on geometry with no width or height (SVG 2 §8.10).
struct LayerTreePaintServerOpacityTests {

    typealias Command = RendererCommand<LayerTreeTypes>

    enum Server: String, CaseIterable, CustomTestStringConvertible {
        case linear
        case radial
        case pattern

        var testDescription: String { rawValue }

        var defs: String {
            switch self {
            case .linear:
                #"<linearGradient id="p"><stop offset="0" stop-color="white" /><stop offset="1" stop-color="black" /></linearGradient>"#
            case .radial:
                #"<radialGradient id="p"><stop offset="0" stop-color="white" /><stop offset="1" stop-color="black" /></radialGradient>"#
            case .pattern:
                #"<pattern id="p" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="2" height="2" fill="green" /></pattern>"#
            }
        }

        func paints(_ command: Command) -> Bool {
            switch (self, command) {
            case (.linear, .drawLinearGradient), (.radial, .drawRadialGradient), (.pattern, .setFillPattern):
                return true
            default:
                return false
            }
        }
    }

    @Test(arguments: Server.allCases)
    func strokeOpacityAppliesToPaintServer(_ server: Server) throws {
        let commands = try makeCommands(server, #"fill="none" stroke="url(#p)" stroke-opacity="0.5" stroke-width="4""#)
        let paint = try #require(commands.firstIndex(where: server.paints))
        #expect(commands.lastAlpha(before: paint) == 0.5)
        #expect(commands[..<paint].contains { if case .clipStrokeOutline = $0 { return true }; return false })
    }

    @Test(arguments: Server.allCases)
    func fillOpacityAppliesToPaintServer(_ server: Server) throws {
        let commands = try makeCommands(server, #"fill="url(#p)" fill-opacity="0.25""#)
        let paint = try #require(commands.firstIndex(where: server.paints))
        #expect(commands.lastAlpha(before: paint) == 0.25)
    }

    @Test(arguments: Server.allCases)
    func fillOpacityDoesNotLeakIntoStroke(_ server: Server) throws {
        let commands = try makeCommands(server, #"fill="none" fill-opacity="0.3" stroke="url(#p)" stroke-width="4""#)
        let paint = try #require(commands.firstIndex(where: server.paints))
        #expect(commands.lastAlpha(before: paint) ?? 1 == 1)
    }

    @Test
    func patternStrokeIsClippedToTheStrokeOutline() throws {
        let commands = try makeCommands(.pattern, #"fill="none" stroke="url(#p)" stroke-width="4""#)
        #expect(commands.names == [
            "pushState", "setLineCap", "setLineJoin", "setLineWidth", "setLineMiterLimit",
            "clipStrokeOutline", "setFillPattern", "fillPath", "popState"
        ])
        let fill = try #require(commands.compactMap { if case .fill(let path, _) = $0 { return path }; return nil }.first)
        // the rect outset by the stroke's reach at miter joins (half the width × miterlimit 4)
        #expect(fill == [.rect(within: .init(x: -8, y: -8, width: 26, height: 36), radii: .zero)])
    }

    @Test
    func patternStrokeResolvesObjectBoundingBoxAgainstGeometry() throws {
        let pattern = #"<pattern id="p" width="0.5" height="0.5"><rect width="1" height="1" fill="green" /></pattern>"#
        let commands = try makeCommands(defs: pattern, #"fill="none" stroke="url(#p)" stroke-width="4""#)
        let resolved = try #require(commands.compactMap { if case .setFillPattern(let p) = $0 { return p }; return nil }.first)
        #expect(resolved.frame == .init(x: 0, y: 0, width: 5, height: 10))
    }

    @Test(arguments: [
        #"<linearGradient id="p"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></linearGradient>"#,
        #"<radialGradient id="p"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></radialGradient>"#,
        #"<pattern id="p" width="1" height="1"><rect width="1" height="1" fill="red" /></pattern>"#
    ])
    func objectBoundingBoxServerOnLineUsesFallback(_ defs: String) throws {
        let commands = try makeCommands(defs: defs, shape: "line", #"x1="0" y1="5" x2="10" y2="5" stroke="url(#p) #00ff00" stroke-width="2""#)
        #expect(commands.strokeColors == [.init(0, 255, 0)])
    }

    @Test
    func userSpaceServerOnLineIgnoresFallback() throws {
        let gradient = #"<linearGradient id="p" gradientUnits="userSpaceOnUse" x1="0" x2="10"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></linearGradient>"#
        let commands = try makeCommands(defs: gradient, shape: "line", #"x1="0" y1="5" x2="10" y2="5" stroke="url(#p) #00ff00" stroke-width="2""#)
        #expect(commands.strokeColors.isEmpty)
        #expect(commands.contains { if case .drawLinearGradient = $0 { return true }; return false })
    }

    func makeCommands(_ server: Server, _ attributes: String) throws -> [Command] {
        try makeCommands(defs: server.defs, attributes)
    }

    func makeCommands(defs: String, shape: String = "rect", _ attributes: String) throws -> [Command] {
        let geometry = shape == "rect" ? #"width="10" height="20" "# : ""
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
            <defs>\(defs)</defs>
            <\(shape) \(geometry)\(attributes) />
        </svg>
        """)
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(20, 20), options: .default)
        return generator.renderCommands(for: LayerTree.Builder(svg: svg).makeLayer(), colorConverter: .default)
    }
}

private extension Array where Element == RendererCommand<LayerTreeTypes> {

    var names: [String] {
        let renderer = MockRenderer()
        renderer.perform(self)
        return renderer.operations
    }

    var strokeColors: [LayerTree.Color] {
        compactMap { if case .setStroke(let c) = $0 { return c }; return nil }
    }

    func lastAlpha(before index: Int) -> LayerTree.Float? {
        self[..<index].lazy.reversed().compactMap { if case .setAlpha(let a) = $0 { return a }; return nil }.first
    }
}
