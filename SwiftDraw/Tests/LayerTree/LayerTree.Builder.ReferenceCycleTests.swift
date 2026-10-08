//
//  LayerTree.Builder.ReferenceCycleTests.swift
//  SwiftDraw
//  Created by Simon Whitty on 21/11/18.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

import SwiftDrawDOM
import XCTest
import Foundation
@testable import SwiftDraw

final class LayerTreeBuilderReferenceCycleTests: XCTestCase {

    private struct Stats {
        var layers = 0
        var shapes = 0
        var maskedLayers = 0
        var patternFills = 0
        var nesting = 0
    }

    private func makeSVG(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: """
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        \(body)
        </svg>
        """)
    }

    private func stats(_ body: String) throws -> Stats {
        let layer = LayerTree.Builder(svg: try makeSVG(body)).makeLayer()
        return Self.stats(of: layer)
    }

    private static func stats(of layer: LayerTree.Layer) -> Stats {
        var stats = Stats()
        collect(layer, depth: 1, into: &stats)
        return stats
    }

    private static func collect(_ layer: LayerTree.Layer, depth: Int, into stats: inout Stats) {
        stats.layers += 1
        stats.nesting = max(stats.nesting, depth)
        if let mask = layer.mask {
            stats.maskedLayers += 1
            collect(mask, depth: depth + 1, into: &stats)
        }
        collect(layer.contents, depth: depth + 1, into: &stats)
    }

    private static func collect(_ contents: [LayerTree.Layer.Contents], depth: Int, into stats: inout Stats) {
        for content in contents {
            switch content {
            case .layer(let l):
                collect(l, depth: depth, into: &stats)
            case .shape(_, _, let fill):
                stats.shapes += 1
                if case .pattern(let pattern) = fill.fill {
                    stats.patternFills += 1
                    collect(pattern.contents, depth: depth + 1, into: &stats)
                }
            case .image, .text:
                break
            }
        }
    }

    /// `<g id="g0"><use href="#g1"/></g> ... <g id="g<count>"><rect/></g>`
    private static func chain(count: Int) -> String {
        var svg = ""
        for i in 0..<count {
            svg += ##"<g id="g\##(i)"><use xlink:href="#g\##(i + 1)"/></g>"##
        }
        svg += ##"<g id="g\##(count)"><rect width="10" height="10"/></g>"##
        return svg
    }

    // MARK: - <use> cycles

    func testUseOfOwnAncestorDrawsNoExtraCopy() throws {
        // rendered directly: the group draws once, the nested use is the error
        let s = try stats(##"<g id="a"><rect width="10" height="10"/><use xlink:href="#a"/></g>"##)
        XCTAssertEqual(s.shapes, 1)
    }

    func testUseOfItselfDrawsNothing() throws {
        let s = try stats(##"<use id="a" xlink:href="#a"/>"##)
        XCTAssertEqual(s.shapes, 0)
    }

    func testMutualCycleRenderedDirectlyDrawsEachGroupOnce() throws {
        let s = try stats(##"""
        <g id="a"><rect width="10" height="10"/><use xlink:href="#b"/></g>
        <g id="b"><rect width="10" height="10"/><use xlink:href="#a"/></g>
        """##)
        XCTAssertEqual(s.shapes, 2)
    }

    func testUseOfCyclicTargetDrawsNothing() throws {
        let s = try stats(##"""
        <defs><g id="a"><rect width="10" height="10"/><use xlink:href="#a"/></g></defs>
        <use xlink:href="#a"/>
        """##)
        XCTAssertEqual(s.shapes, 0)
    }

    func testIndirectCycleThroughTargetDrawsNothing() throws {
        let s = try stats(##"""
        <defs>
          <g id="x"><rect width="10" height="10"/><use xlink:href="#y"/></g>
          <g id="y"><rect width="10" height="10"/><use xlink:href="#x"/></g>
        </defs>
        <use xlink:href="#x"/>
        """##)
        XCTAssertEqual(s.shapes, 0)
    }

    // MARK: - valid references still draw

    func testDiamondDrawsSharedTargetTwice() throws {
        let s = try stats(##"""
        <defs>
          <rect id="d" width="10" height="10"/>
          <g id="b"><use xlink:href="#d"/></g>
          <g id="c"><use xlink:href="#d"/></g>
          <g id="a"><use xlink:href="#b"/><use xlink:href="#c"/></g>
        </defs>
        <use xlink:href="#a"/>
        """##)
        XCTAssertEqual(s.shapes, 2)
    }

    func testRepeatedSiblingUsesAreAllDrawn() throws {
        let s = try stats(##"""
        <defs><rect id="r" width="10" height="10"/></defs>
        <use xlink:href="#r"/><use xlink:href="#r"/><use xlink:href="#r"/>
        """##)
        XCTAssertEqual(s.shapes, 3)
    }

    func testChainUnderTheCapIsDrawnFully() throws {
        let s = try stats(##"<defs>\##(Self.chain(count: 5))</defs><use xlink:href="#g0"/>"##)
        XCTAssertEqual(s.shapes, 1)
    }

    // MARK: - caps

    func testLongChainStopsAtTheCapWithoutCrashing() throws {
        let s = try stats(##"<defs>\##(Self.chain(count: 100))</defs><use xlink:href="#g0"/>"##)
        XCTAssertEqual(s.shapes, 0)
        XCTAssertLessThanOrEqual(s.layers, 4 * LayerTree.Builder.ReferenceGuard.maxDepth + 8)
    }

    func testFanOutIsBoundedByTheReferenceBudget() throws {
        var body = "<defs>"
        for i in 0..<30 {
            body += ##"<g id="g\##(i)"><use xlink:href="#g\##(i + 1)"/><use xlink:href="#g\##(i + 1)"/></g>"##
        }
        body += ##"<g id="g30"><rect width="10" height="10"/></g></defs><use xlink:href="#g0"/>"##
        let s = try stats(body)
        XCTAssertLessThanOrEqual(s.layers, 10 * LayerTree.Builder.ReferenceGuard.maxReferences)
    }

    func testCapDepthFitsASmallSecondaryThreadStack() throws {
        let maxDepth = LayerTree.Builder.ReferenceGuard.maxDepth
        nonisolated(unsafe) let svg = try makeSVG(##"<defs>\##(Self.chain(count: maxDepth - 1))</defs><use xlink:href="#g0"/>"##)
        nonisolated(unsafe) var result = Stats()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            result = Self.stats(of: LayerTree.Builder(svg: svg).makeLayer())
            done.signal()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        XCTAssertEqual(done.wait(timeout: .now() + 30), .success)
        XCTAssertEqual(result.shapes, 1)
    }

    // MARK: - mask, pattern, gradient

    func testMaskReferencingItselfIsDroppedInsideTheMask() throws {
        let s = try stats(##"""
        <mask id="m"><rect width="10" height="10" mask="url(#m)"/></mask>
        <rect width="10" height="10" mask="url(#m)"/>
        """##)
        XCTAssertEqual(s.maskedLayers, 1)
    }

    func testPatternPaintedWithItselfIsDroppedInsideThePattern() throws {
        let s = try stats(##"""
        <pattern id="p" width="10" height="10" patternUnits="userSpaceOnUse">
          <rect width="5" height="5" fill="url(#p)"/>
        </pattern>
        <rect width="10" height="10" fill="url(#p)"/>
        """##)
        XCTAssertEqual(s.patternFills, 1)
    }

    func testPatternHrefCycleStillPaints() throws {
        let s = try stats(##"""
        <pattern id="a" xlink:href="#b" width="10" height="10" patternUnits="userSpaceOnUse"/>
        <pattern id="b" xlink:href="#a"><rect width="5" height="5"/></pattern>
        <rect width="10" height="10" fill="url(#a)"/>
        """##)
        XCTAssertEqual(s.patternFills, 1)
        XCTAssertEqual(s.shapes, 2) // the filled rect and the rect inherited from #b
    }

    func testPatternHrefChainStopsAtTheCap() throws {
        var body = ""
        for i in 0..<100 {
            body += ##"<pattern id="p\##(i)" xlink:href="#p\##(i + 1)" width="10" height="10" patternUnits="userSpaceOnUse"/>"##
        }
        body += ##"<pattern id="p100"><rect width="5" height="5"/></pattern><rect width="10" height="10" fill="url(#p0)"/>"##
        let s = try stats(body)
        // the content lives past the cap, so it is not inherited; the document still renders
        XCTAssertEqual(s.patternFills, 1)
        XCTAssertEqual(s.shapes, 1)
    }

    func testGradientHrefCycleDoesNotRecurse() throws {
        let s = try stats(##"""
        <linearGradient id="a" xlink:href="#b"/>
        <linearGradient id="b" xlink:href="#a"/>
        <rect width="10" height="10" fill="url(#a)"/>
        """##)
        XCTAssertEqual(s.shapes, 1)
    }
}
