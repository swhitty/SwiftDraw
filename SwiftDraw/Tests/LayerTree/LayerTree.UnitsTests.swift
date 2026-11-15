//
//  LayerTree.UnitsTests.swift
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


@testable import SwiftDraw
@testable import SwiftDrawDOM
import Testing

// SD13 — SVG 1.1 §7.10: units and percentages reach the renderers in user units
struct LayerTreeUnitsTests {

    typealias Command = RendererCommand<LayerTreeTypes>

    private func commands(_ xml: String) throws -> [Command] {
        let svg = try DOM.SVG.parse(xml: xml)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    private func fills(_ commands: [Command]) -> [LayerTree.Rect] {
        commands.compactMap {
            guard case let .fill(shapes, rule: _) = $0 else { return nil }
            let bounds = shapes.map(\.path.bounds)
            guard let first = bounds.first else { return nil }
            return bounds.dropFirst().reduce(first, union)
        }
    }

    private func union(_ a: LayerTree.Rect, _ b: LayerTree.Rect) -> LayerTree.Rect {
        let minX = min(a.minX, b.minX), minY = min(a.minY, b.minY)
        return LayerTree.Rect(x: minX, y: minY,
                              width: max(a.maxX, b.maxX) - minX,
                              height: max(a.maxY, b.maxY) - minY)
    }

    private func transforms(_ commands: [Command]) -> [String] {
        commands.compactMap {
            switch $0 {
            case let .translate(tx, ty): return "translate(\(tx), \(ty))"
            case let .scale(sx, sy): return "scale(\(sx), \(sy))"
            case .concatenate: return "concatenate"
            default: return nil
            }
        }
    }

    @Test
    func percentagesAndUnitsReachTheFillCommand() throws {
        let commands = try commands("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
        <rect x="10%" y="1in" width="50%" height="25.4mm" fill="red"/>
        <circle cx="50%" cy="50%" r="2em" fill="red"/>
        </svg>
        """)
        let fills = fills(commands)
        #expect(fills.count == 2)
        #expect(abs(try #require(fills.first?.x) - 20) < 0.001)
        #expect(abs(try #require(fills.first?.y) - 96) < 0.001)
        #expect(abs(try #require(fills.first?.width) - 100) < 0.001)
        #expect(abs(try #require(fills.first?.height) - 96) < 0.001)
        // r = 2em = 32 at the initial 16px font-size
        #expect(abs(try #require(fills.last?.midX) - 100) < 0.01)
        #expect(abs(try #require(fills.last?.width) - 64) < 0.01)
    }

    @Test
    func fractionalRootWithMatchingViewBoxHasNoTransform() throws {
        // stored as Int, 145.11934 became 145 and the viewBox was letterboxed by a fraction of a unit
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="145.11934" height="80" viewBox="0 0 145.11934 80">
        <rect width="10" height="10"/></svg>
        """)
        #expect(svg.width == 145.11934)
        #expect(LayerTree.Builder(svg: svg).makeLayer().transform == [])
    }

    @Test
    func rootWithOnlyWidthScalesTheViewBoxUniformly() throws {
        // browsers draw width="200" viewBox="0 0 100 50" at 200x100, a uniform x2
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" viewBox="0 0 100 50"><rect width="100" height="50"/></svg>
        """)
        #expect(svg.width == 200)
        #expect(svg.height == 100)
        #expect(LayerTree.Builder(svg: svg).makeLayer().transform == [.scale(sx: 2, sy: 2)])
    }

    @Test
    func nestedSVGPercentagesUseTheEnclosingViewport() throws {
        // nested viewport: x=50 y=10 100x80; its 10x10 viewBox meets at x8, centred 10 units right
        let commands = try commands("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
        <svg x="25%" y="10%" width="50%" height="80%" viewBox="0 0 10 10">
        <rect width="50%" height="100%" fill="red"/></svg>
        </svg>
        """)
        #expect(transforms(commands) == ["translate(60.0, 10.0)", "scale(8.0, 8.0)"])
        #expect(fills(commands) == [LayerTree.Rect(x: 0, y: 0, width: 5, height: 10)])
    }
}
