//
//  CGPatternTests.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
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
@testable import SwiftDrawDOM
import XCTest

/// Pattern fills reset the optimizer's tracked fill, and `fill="url(#id) fallback"` (SVG 1.1 §11.2).
final class LayerTreePaintFallbackTests: XCTestCase {

    func testOptimizerKeepsSetFillAfterPattern() {
        let commands: [RendererCommand<LayerTreeTypes>] = [
            .setFill(color: .black),
            .setFillPattern(LayerTree.Pattern(frame: .init(x: 0, y: 0, width: 2, height: 2))),
            .setFill(color: .black)
        ]
        let optimized = LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
        XCTAssertEqual(optimized.names, ["setFillColor", "setFillPattern", "setFillColor"])
    }

    func testOptimizerStillDropsRepeatedFill() {
        let commands: [RendererCommand<LayerTreeTypes>] = [
            .setFill(color: .black),
            .setFill(color: .black)
        ]
        let optimized = LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
        XCTAssertEqual(optimized.names, ["setFillColor"])
    }

    func testPatternThenSameColourEndToEnd() throws {
        let commands = try makeCommands(fill: "#000000", then: "url(#pat)", defs: pattern)
        XCTAssertEqual(commands.names.filter { $0 == "setFillColor" }.count, 2)
        XCTAssertEqual(commands.names.filter { $0 == "setFillPattern" }.count, 1)
    }

    func testResolvingServerWinsOverFallback() throws {
        let commands = try makeCommands(fill: "url(#g) #ff0000", defs: gradient)
        XCTAssertTrue(commands.names.contains("drawLinearGradient"))
    }

    func testMissingServerUsesFallbackColour() throws {
        let commands = try makeCommands(fill: "url(#missing) #ff0000")
        XCTAssertEqual(commands.fillColors, [.init(255, 0, 0)])
    }

    func testMissingServerWithNoneFallbackPaintsNothing() throws {
        let commands = try makeCommands(fill: "url(#missing) none")
        XCTAssertFalse(commands.names.contains("fill"))
    }

    func testMissingServerWithoutFallbackPaintsNothing() throws {
        let commands = try makeCommands(fill: "url(#missing)")
        XCTAssertFalse(commands.names.contains("fill"))
    }

    func testFallbackInStyleAttribute() throws {
        let commands = try makeCommands(fill: nil, style: "fill:url(#missing) #ff0000")
        XCTAssertEqual(commands.fillColors, [.init(255, 0, 0)])
    }

    func testStrokeFallback() throws {
        let svg = try DOM.SVG.parse(xml: #"""
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
            <rect width="5" height="5" fill="none" stroke="url(#missing) #00ff00" stroke-width="2" />
        </svg>
        """#)
        let commands = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(10, 10), options: .default)
            .renderCommands(for: LayerTree.Builder(svg: svg).makeLayer(), colorConverter: .default)
        XCTAssertTrue(commands.contains { if case .setStroke(let c) = $0 { return c == .init(0, 255, 0) }; return false })
    }

    func testUnreadableFallbackIsDroppedNotTheServer() throws {
        let commands = try makeCommands(fill: "url(#g) garbage", defs: gradient)
        XCTAssertTrue(commands.names.contains("drawLinearGradient"))
    }

    var pattern: String {
        #"<pattern id="pat" width="2" height="2" patternUnits="userSpaceOnUse"><rect width="1" height="1" fill="white" /></pattern>"#
    }

    var gradient: String {
        #"<linearGradient id="g"><stop offset="0" stop-color="blue" /><stop offset="1" stop-color="white" /></linearGradient>"#
    }

    func makeCommands(fill first: String?, then second: String? = nil, style: String? = nil, defs: String = "") throws -> [RendererCommand<LayerTreeTypes>] {
        func rect(_ fill: String?, _ style: String?) -> String {
            "<rect width=\"10\" height=\"10\"\(fill.map { " fill=\"\($0)\"" } ?? "")\(style.map { " style=\"\($0)\"" } ?? "") />"
        }
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
            <defs>\(defs)</defs>
            \(rect(first, style))
            \(second.map { rect($0, nil) } ?? "")
            \(second != nil ? rect(first, nil) : "")
        </svg>
        """)
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .init(10, 10), options: .default)
        let commands = generator.renderCommands(for: LayerTree.Builder(svg: svg).makeLayer(), colorConverter: .default)
        return LayerTree.CommandOptimizer<LayerTreeTypes>().optimizeCommands(commands)
    }
}

private extension Array where Element == RendererCommand<LayerTreeTypes> {

    var names: [String] {
        let renderer = MockRenderer()
        renderer.perform(self)
        return renderer.operations
    }

    var fillColors: [LayerTree.Color] {
        compactMap { if case .setFill(let c) = $0 { return c }; return nil }
    }
}
