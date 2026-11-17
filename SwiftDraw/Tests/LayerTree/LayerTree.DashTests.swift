//
//  LayerTree.DashTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 13/12/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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
import Foundation
import Testing

struct LayerTreeDashTests {

    private func commandStream(_ body: String) throws -> [RendererCommand<LayerTreeProvider.Types>] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    private func dashes(_ svgBody: String, attributes: String = "") throws -> [(phase: Float, lengths: [Float])] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" \(attributes)>\(svgBody)</svg>
                """
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default).compactMap {
            if case let .setLineDash(phase: p, lengths: l) = $0, !l.isEmpty { return (p, l) }
            return nil
        }
    }

    @Test
    func basicDashAndOffset() throws {
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 2" stroke-dashoffset="1"/>"#)
        #expect(d.count == 1)
        #expect(d[0].lengths == [4, 2])
        #expect(d[0].phase == 1)
    }

    @Test
    func oddListRepeats() throws {
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="5,3,2"/>"#)
        #expect(d[0].lengths == [5, 3, 2, 5, 3, 2])
    }

    /// A negative value, garbage or a non-finite value invalidates the attribute without dropping the document.
    @Test(arguments: ["4 -2", "abc", "nan% 5", "inf 5"])
    func invalidDasharrayIsIgnored(_ dasharray: String) throws {
        #expect(try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="\#(dasharray)"/>"#).isEmpty)
    }

    @Test
    func allZeroIsSolid() throws {
        #expect(try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="0 0"/>"#).isEmpty)
    }

    @Test
    func noneOverridesInherited() throws {
        let d = try dashes(
            #"<g stroke-dasharray="4 2"><path d="M0 0 L5 5" stroke="black" stroke-dasharray="none"/><path d="M0 0 L9 9" stroke="black"/></g>"#
        )
        #expect(d.count == 1)
        #expect(d[0].lengths == [4, 2])
    }

    @Test
    func styleAttributeAndGroupInheritance() throws {
        let d = try dashes(
            #"<g style="stroke-dasharray: 6 3; stroke-dashoffset: 2"><path d="M0 0 L50 50" stroke="black"/></g>"#
        )
        #expect(d[0].lengths == [6, 3])
        #expect(d[0].phase == 2)
    }

    @Test
    func percentageRelativeToViewportDiagonal() throws {
        // width=height=100 => normalized diagonal = 100
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="10% 5%"/>"#)
        #expect(d[0].lengths[0].isApproximately(10, tolerance: 0.001))
        #expect(d[0].lengths[1].isApproximately(5, tolerance: 0.001))
    }

    @Test
    func solidStrokeEmitsNoDashCommand() throws {
        #expect(try dashes(#"<path d="M0 0 L50 50" stroke="black"/>"#).isEmpty)
    }

    @Test
    func dashIsBracketedByPushAndPop() throws {
        let commands = try commandStream(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 2"/>"#)
        let names = commands.map { String(describing: $0).prefix(while: { $0 != "(" }) }
        let dash = try #require(names.firstIndex(of: "setLineDash"))
        let stroke = try #require(names.firstIndex(of: "stroke"))
        #expect(names[dash - 5] == "pushState")  // push, cap, join, width, miter, dash
        #expect(stroke > dash)
        // explicit reset after the stroke, then pop
        guard case let .setLineDash(phase: phase, lengths: lengths) = commands[stroke + 1] else {
            Issue.record("expected dash reset after stroke")
            return
        }
        #expect(phase == 0)
        #expect(lengths == [])
        #expect(names[stroke + 2] == "popState")
    }

    @Test
    func percentageNonSquareViewport() throws {
        let d = try dashes(
            #"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="10% 10%"/>"#,
            attributes: #"viewBox="0 0 200 100""#
        )
        // viewBox 200x100: sqrt((200² + 100²) / 2) = 158.11
        #expect(d[0].lengths[0].isApproximately(15.811, tolerance: 0.01))
    }

    @Test
    func percentageUsesViewBoxNotWidthHeight() throws {
        let d = try dashes(
            #"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="10% 10%"/>"#,
            attributes: #"viewBox="0 0 50 50""#
        )
        #expect(d[0].lengths[0].isApproximately(5, tolerance: 0.001))
    }

    @Test
    func negativeOffsetIsKept() throws {
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 2" stroke-dashoffset="-3"/>"#)
        #expect(d[0].phase == -3)
    }

    @Test
    func invalidChildDasharrayInheritsFromDashedGroup() throws {
        let d = try dashes(
            #"<g stroke-dasharray="4 2"><path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 -2"/></g>"#
        )
        #expect(d.count == 1)
        #expect(d[0].lengths == [4, 2])
    }

    @Test
    func styleNoneOverridesGroup() throws {
        let d = try dashes(
            #"<g stroke-dasharray="4 2"><path d="M0 0 L50 50" stroke="black" style="stroke-dasharray:none"/></g>"#
        )
        #expect(d.isEmpty)
    }

    @Test
    func nonFiniteOffsetIsZero() throws {
        let d = try dashes(#"<path d="M0 0 L50 50" stroke="black" stroke-dasharray="4 2" stroke-dashoffset="nan%"/>"#)
        #expect(d[0].phase == 0)
    }
}
