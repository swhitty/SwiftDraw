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


import XCTest
@testable import SwiftDraw
@testable import SwiftDrawDOM

// SD13 — SVG 1.1 §7.10: units and percentages reach the renderers in user units
final class LayerTreeUnitsTests: XCTestCase {

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
            return shapes.map(\.path.bounds).reduce(nil as LayerTree.Rect?) { acc, b in acc.map { $0.union(b) } ?? b }
        }
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

    func testPercentagesAndUnitsReachTheFillCommand() throws {
        let commands = try commands("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
        <rect x="10%" y="1in" width="50%" height="25.4mm" fill="red"/>
        <circle cx="50%" cy="50%" r="2em" fill="red"/>
        </svg>
        """)
        let fills = fills(commands)
        XCTAssertEqual(fills.count, 2)
        XCTAssertEqual(fills.first?.x ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(fills.first?.y ?? 0, 96, accuracy: 0.001)
        XCTAssertEqual(fills.first?.width ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(fills.first?.height ?? 0, 96, accuracy: 0.001)
        // r = 2em = 32 at the initial 16px font-size
        XCTAssertEqual(fills.last?.midX ?? 0, 100, accuracy: 0.01)
        XCTAssertEqual(fills.last?.width ?? 0, 64, accuracy: 0.01)
    }

    func testFractionalRootWithMatchingViewBoxHasNoTransform() throws {
        // stored as Int, 145.11934 became 145 and the viewBox was letterboxed by a fraction of a unit
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="145.11934" height="80" viewBox="0 0 145.11934 80">
        <rect width="10" height="10"/></svg>
        """)
        XCTAssertEqual(svg.width, 145.11934)
        XCTAssertEqual(LayerTree.Builder(svg: svg).makeLayer().transform, [])
    }

    func testRootWithOnlyWidthScalesTheViewBoxUniformly() throws {
        // browsers draw width="200" viewBox="0 0 100 50" at 200x100, a uniform x2
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" viewBox="0 0 100 50"><rect width="100" height="50"/></svg>
        """)
        XCTAssertEqual(svg.width, 200)
        XCTAssertEqual(svg.height, 100)
        XCTAssertEqual(LayerTree.Builder(svg: svg).makeLayer().transform, [.scale(sx: 2, sy: 2)])
    }

    func testNestedSVGPercentagesUseTheEnclosingViewport() throws {
        // nested viewport: x=50 y=10 100x80; its 10x10 viewBox meets at x8, centred 10 units right
        let commands = try commands("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
        <svg x="25%" y="10%" width="50%" height="80%" viewBox="0 0 10 10">
        <rect width="50%" height="100%" fill="red"/></svg>
        </svg>
        """)
        XCTAssertEqual(transforms(commands), ["translate(60.0, 10.0)", "scale(8.0, 8.0)"])
        XCTAssertEqual(fills(commands), [LayerTree.Rect(x: 0, y: 0, width: 5, height: 10)])
    }
}
