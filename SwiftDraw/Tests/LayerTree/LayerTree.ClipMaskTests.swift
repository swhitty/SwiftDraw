//
//  LayerTree.ClipMaskTests.swift
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

import XCTest
@testable import SwiftDraw
import Foundation

/// SD8: clip paths and masks to spec (SVG 1.1 §14.3.5, §14.4). Asserts on the command stream.
final class LayerTreeClipMaskTests: XCTestCase {

    typealias Command = RendererCommand<LayerTreeProvider.Types>

    private func commands(_ body: String) throws -> [Command] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">\(body)</svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    private func clips(_ commands: [Command]) -> [(bounds: LayerTree.Rect, rule: LayerTree.FillRule)] {
        commands.compactMap {
            guard case let .setClip(path: shapes, rule: rule) = $0 else { return nil }
            return (bounds(shapes), rule)
        }
    }

    private func fills(_ commands: [Command]) -> [(bounds: LayerTree.Rect, rule: LayerTree.FillRule)] {
        commands.compactMap {
            guard case let .fill(shapes, rule: rule) = $0 else { return nil }
            return (bounds(shapes), rule)
        }
    }

    private func bounds(_ shapes: [LayerTree.Shape]) -> LayerTree.Rect {
        shapes.map(\.path.bounds).reduce(nil as LayerTree.Rect?) { acc, b in acc.map { $0.union(b) } ?? b } ?? .zero
    }

    private func transparencyLayers(_ commands: [Command]) -> Int {
        commands.filter { if case .pushTransparencyLayer = $0 { return true } else { return false } }.count
    }

    private func assertRect(_ rect: LayerTree.Rect?, _ x: Float, _ y: Float, _ w: Float, _ h: Float,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let rect else { return XCTFail("no rect", file: file, line: line) }
        XCTAssertEqual(rect.x, x, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(rect.y, y, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(rect.width, w, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(rect.height, h, accuracy: 0.001, file: file, line: line)
    }

    // MARK: - clipPathUnits

    func testClipPathUnitsObjectBoundingBox() throws {
        let c = try commands("""
        <clipPath id="c" clipPathUnits="objectBoundingBox"><rect x="0.25" y="0.25" width="0.5" height="0.5"/></clipPath>
        <rect x="20" y="20" width="60" height="60" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).count, 1)
        assertRect(clips(c).first?.bounds, 35, 35, 30, 30)
    }

    func testClipPathUnitsObjectBoundingBoxOfGroup() throws {
        // group bounds: union of (0,0,20,20) and (60,40,40,40 translated by 0,20) = (0,0,100,100)
        let c = try commands("""
        <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
        <g clip-path="url(#c)">
          <rect width="20" height="20"/>
          <rect x="60" y="40" width="40" height="40" transform="translate(0 20)"/>
        </g>
        """)
        assertRect(clips(c).first?.bounds, 0, 0, 50, 100)
    }

    func testClipPathUnitsObjectBoundingBoxIgnoresElementTransform() throws {
        // the clip lives in the element's user space, after its own transform
        let c = try commands("""
        <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="0.5"/></clipPath>
        <rect x="10" y="10" width="20" height="20" transform="scale(2)" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 10, 10, 10, 10)
    }

    func testClipPathUnitsObjectBoundingBoxAppliesClipPathTransform() throws {
        let c = try commands("""
        <clipPath id="c" clipPathUnits="objectBoundingBox" transform="translate(0.5 0)"><rect width="0.5" height="1"/></clipPath>
        <rect width="40" height="40" clip-path="url(#c)"/>
        """)
        // the bbox mapping comes first, then the transform in user units (Blink, Gecko, resvg)
        assertRect(clips(c).first?.bounds, 0.5, 0, 20, 40)
    }

    func testClipPathUnitsObjectBoundingBoxOfEmptyBoxClipsEverything() throws {
        let c = try commands("""
        <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="1" height="1"/></clipPath>
        <line x1="0" y1="10" x2="100" y2="10" stroke="black" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 0, 0, 0, 0)
    }

    func testClipPathUnitsUserSpaceOnUse() throws {
        let c = try commands("""
        <clipPath id="c" clipPathUnits="userSpaceOnUse"><rect x="5" y="5" width="10" height="10"/></clipPath>
        <rect x="20" y="20" width="60" height="60" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 5, 5, 10, 10)
    }

    func testInvalidClipPathUnitsKeepsDocument() throws {
        let c = try commands("""
        <clipPath id="c" clipPathUnits="bogus"><rect x="5" y="5" width="10" height="10"/></clipPath>
        <rect x="20" y="20" width="60" height="60" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 5, 5, 10, 10)
        XCTAssertEqual(fills(c).count, 1)
    }

    // MARK: - clip-rule

    func testClipRuleOnClipPathChild() throws {
        let c = try commands("""
        <clipPath id="c"><rect width="10" height="10" clip-rule="evenodd"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).first?.rule, .evenodd)
    }

    func testClipRuleInheritedFromClipPath() throws {
        let c = try commands("""
        <clipPath id="c" clip-rule="evenodd"><rect width="10" height="10"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).first?.rule, .evenodd)
    }

    func testClipRuleOnChildOverridesClipPath() throws {
        let c = try commands("""
        <clipPath id="c" clip-rule="evenodd"><rect width="10" height="10" clip-rule="nonzero"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).first?.rule, .nonzero)
    }

    func testClipRuleOnReferencingElementIsNotUsed() throws {
        // clip-rule is inherited by the <clipPath> contents from the <clipPath>, not from the element it clips
        let c = try commands("""
        <clipPath id="c"><rect width="10" height="10"/></clipPath>
        <rect width="50" height="50" clip-rule="evenodd" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).first?.rule, .nonzero)
    }

    func testClipRuleFromStyleAttribute() throws {
        let c = try commands("""
        <clipPath id="c"><path d="M0 0h10v10h-10z" style="clip-rule:evenodd"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).first?.rule, .evenodd)
    }

    func testMixedClipRulesBecomeMask() throws {
        let c = try commands("""
        <clipPath id="c">
          <rect width="10" height="10" clip-rule="evenodd"/>
          <rect x="20" width="10" height="10"/>
        </clipPath>
        <rect width="50" height="50" fill="red" clip-path="url(#c)"/>
        """)
        XCTAssertTrue(clips(c).isEmpty)
        XCTAssertGreaterThan(transparencyLayers(c), 0)
        let maskFills = fills(c).filter { $0.bounds.width == 10 }
        XCTAssertEqual(maskFills.map(\.rule), [.evenodd, .nonzero])
    }

    // MARK: - <use> and <text> inside <clipPath>

    func testUseInsideClipPath() throws {
        let c = try commands("""
        <defs><rect id="r" width="10" height="10" transform="translate(1 2)"/></defs>
        <clipPath id="c"><use xlink:href="#r" x="20" y="30" transform="scale(2)"/></clipPath>
        <rect width="100" height="100" clip-path="url(#c)"/>
        """)
        // rect → translate(1,2) → translate(20,30) → scale(2)
        assertRect(clips(c).first?.bounds, 42, 64, 20, 20)
    }

    func testUseInsideClipPathInheritsClipRule() throws {
        let c = try commands("""
        <defs><rect id="r" width="10" height="10"/></defs>
        <clipPath id="c"><use xlink:href="#r" clip-rule="evenodd"/></clipPath>
        <rect width="100" height="100" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(clips(c).first?.rule, .evenodd)
    }

    func testUseOfGroupInsideClipPathIsIgnored() throws {
        let c = try commands("""
        <defs><g id="g"><rect width="10" height="10"/></g></defs>
        <clipPath id="c"><use xlink:href="#g"/></clipPath>
        <rect width="100" height="100" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 0, 0, 0, 0)
    }

    func testTextInsideClipPathBecomesMask() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <clipPath id="c"><text x="10" y="50" fill="black">Hi</text></clipPath>
          <rect width="100" height="100" fill="red" clip-path="url(#c)"/>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = try XCTUnwrap(findLayer(in: layer) { $0.mask != nil })
        XCTAssertTrue(clipped.clip.isEmpty)
        let texts = allContents(of: try XCTUnwrap(clipped.mask)).compactMap { c -> LayerTree.TextAttributes? in
            if case let .text(_, _, att) = c { return att } else { return nil }
        }
        XCTAssertEqual(texts.map(\.color), [.white])
    }

    func testEmptyClipPathClipsEverything() throws {
        let c = try commands("""
        <clipPath id="c"></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 0, 0, 0, 0)
    }

    func testHiddenClipPathChildIsIgnored() throws {
        let c = try commands("""
        <clipPath id="c"><rect width="10" height="10"/><rect x="40" width="10" height="10" display="none"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        assertRect(clips(c).first?.bounds, 0, 0, 10, 10)
    }

    // MARK: - clip-path on <clipPath>

    func testClipPathOnClipPathIntersects() throws {
        let c = try commands("""
        <clipPath id="inner"><rect x="5" y="5" width="10" height="10"/></clipPath>
        <clipPath id="c" clip-path="url(#inner)"><rect width="10" height="10"/></clipPath>
        <rect width="50" height="50" fill="red" clip-path="url(#c)"/>
        """)
        // the outer clip is drawn as a mask, clipped by the inner one
        XCTAssertGreaterThan(transparencyLayers(c), 0)
        assertRect(clips(c).first?.bounds, 5, 5, 10, 10)
        XCTAssertEqual(fills(c).map(\.bounds.width), [50, 10])
    }

    func testSelfReferencingClipPathKeepsDocument() throws {
        let c = try commands("""
        <clipPath id="c" clip-path="url(#c)"><rect width="10" height="10"/></clipPath>
        <rect width="50" height="50" clip-path="url(#c)"/>
        """)
        XCTAssertFalse(fills(c).isEmpty)
    }

    func testClipAndMaskTogether() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <mask id="m"><rect width="100" height="100" fill="white"/></mask>
          <clipPath id="c"><text x="10" y="50">Hi</text></clipPath>
          <rect width="100" height="100" fill="red" mask="url(#m)" clip-path="url(#c)"/>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let masked = try XCTUnwrap(findLayer(in: layer) { $0.mask != nil })
        // the clip masks the mask's own contents
        let inner = try XCTUnwrap(findLayer(in: try XCTUnwrap(masked.mask)) { $0.mask != nil })
        XCTAssertFalse(allContents(of: try XCTUnwrap(inner.mask)).isEmpty)
    }

    // MARK: - masks

    func testMaskRegionDefaultsToBoundingBoxPlusTenPercent() throws {
        let c = try commands("""
        <mask id="m"><rect width="100" height="100" fill="white"/></mask>
        <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
        """)
        assertRect(clips(c).first?.bounds, 5, 16, 60, 48)
    }

    func testMaskRegionObjectBoundingBox() throws {
        let c = try commands("""
        <mask id="m" x="0" y="0.5" width="50%" height="0.5"><rect width="100" height="100" fill="white"/></mask>
        <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
        """)
        assertRect(clips(c).first?.bounds, 10, 40, 25, 20)
    }

    func testMaskRegionUserSpaceOnUse() throws {
        let c = try commands("""
        <mask id="m" maskUnits="userSpaceOnUse" x="5" y="10%" width="20" height="50%"><rect width="100" height="100" fill="white"/></mask>
        <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
        """)
        assertRect(clips(c).first?.bounds, 5, 10, 20, 50)
    }

    func testMaskContentUnitsObjectBoundingBox() throws {
        let c = try commands("""
        <mask id="m" maskContentUnits="objectBoundingBox"><rect width="0.5" height="1" fill="white"/></mask>
        <rect x="10" y="20" width="50" height="40" fill="red" mask="url(#m)"/>
        """)
        // the content rect is scaled by the bounding box: (10,20,25,40)
        let scale = c.compactMap { cmd -> LayerTree.Transform? in
            if case let .concatenate(transform: t) = cmd { return t } else { return nil }
        }
        XCTAssertEqual(scale, [.matrix(.init(a: 50, b: 0, c: 0, d: 40, tx: 10, ty: 20))])
        XCTAssertEqual(fills(c).map(\.bounds.width), [50, 0.5])
    }

    func testMaskZeroRegionHidesElement() throws {
        let c = try commands("""
        <mask id="m" width="0"><rect width="100" height="100" fill="white"/></mask>
        <rect x="10" y="20" width="50" height="40" fill="red" mask="url(#m)"/>
        """)
        // the element is drawn into a transparency layer, but the mask draws nothing into its
        // destination-in layer, so nothing survives
        let blend = try XCTUnwrap(c.firstIndex { if case .setBlend = $0 { return true } else { return false } })
        XCTAssertEqual(fills(Array(c[..<blend])).count, 1)
        XCTAssertTrue(fills(Array(c[blend...])).isEmpty)
    }

    func testMaskContentUnitsObjectBoundingBoxOnEmptyBoxHidesElement() throws {
        let c = try commands("""
        <mask id="m" maskContentUnits="objectBoundingBox"><rect width="1" height="1" fill="white"/></mask>
        <line x1="0" y1="10" x2="100" y2="10" stroke="red" mask="url(#m)"/>
        """)
        // the mask draws nothing between its destination-in blend and the end of the stream
        let blend = try XCTUnwrap(c.lastIndex { if case .setBlend = $0 { return true } else { return false } })
        XCTAssertTrue(fills(Array(c[blend...])).isEmpty)
        XCTAssertGreaterThan(transparencyLayers(c), 0)
    }

    func testInvalidMaskAttributesKeepDocument() throws {
        let c = try commands("""
        <mask id="m" maskUnits="bogus" maskContentUnits="bogus" x="abc" width=""><rect width="100" height="100" fill="white"/></mask>
        <rect x="10" y="20" width="50" height="40" mask="url(#m)"/>
        """)
        assertRect(clips(c).first?.bounds, 5, 16, 60, 48)
    }

    // MARK: - review round 1

    func testUseOfTextInsideClipPathBecomesMask() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
          <defs><text id="t" x="10" y="50" fill="black">Hi</text></defs>
          <clipPath id="c"><use xlink:href="#t" x="5"/></clipPath>
          <rect width="100" height="100" fill="red" clip-path="url(#c)"/>
        </svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = try XCTUnwrap(findLayer(in: layer) { $0.mask != nil })
        XCTAssertTrue(clipped.maskIsClip)
        let mask = try XCTUnwrap(clipped.mask)
        let texts = allContents(of: mask).compactMap { c -> LayerTree.TextAttributes? in
            if case let .text(_, _, att) = c { return att } else { return nil }
        }
        XCTAssertEqual(texts.map(\.color), [.white])
        // the <use> offset reaches the text's layer
        XCTAssertNotNil(findLayer(in: mask) { $0.transform == [.matrix(.init(a: 1, b: 0, c: 0, d: 1, tx: 5, ty: 0))] })
    }

    func testMutualClipCycleKeepsDocument() throws {
        let c = try commands("""
        <clipPath id="a" clip-path="url(#b)"><rect width="10" height="10"/></clipPath>
        <clipPath id="b" clip-path="url(#a)"><rect width="20" height="20"/></clipPath>
        <rect width="50" height="50" fill="red" clip-path="url(#a)"/>
        """)
        // a → b → (a dropped): b clips a, both are drawn as masks
        XCTAssertEqual(fills(c).map(\.bounds.width), [50, 10, 20])
    }

    func testClipPathInsideMaskContents() throws {
        let c = try commands("""
        <clipPath id="c"><rect width="10" height="10"/></clipPath>
        <mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">
          <rect width="100" height="100" fill="white" clip-path="url(#c)"/>
        </mask>
        <rect width="50" height="50" fill="red" mask="url(#m)"/>
        """)
        XCTAssertEqual(clips(c).map(\.bounds.width), [100, 10])
    }

    func testManyElementsSharingOneClipAllRender() throws {
        // above what the old document-wide budget (20,000 references, three per element here) allowed
        let count = 7_000
        let rects = (0..<count).map { ##"<use xlink:href="#r" x="\##($0 % 100)" clip-path="url(#c)"/>"## }.joined()
        let c = try commands("""
        <defs><rect id="r" width="1" height="1"/></defs>
        <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
        \(rects)
        """)
        XCTAssertEqual(clips(c).count, count)
        XCTAssertEqual(fills(c).count, count)
    }

    func testGroupWithTextHasUnknownBoundingBox() throws {
        // a bbox measured without the text would cut it away: the region and the bbox clip are skipped
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <mask id="m"><rect width="100" height="100" fill="white"/></mask>
          <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
          <g id="masked" mask="url(#m)"><rect width="10" height="10"/><text x="50" y="50">Hi</text></g>
          <g id="clipped" clip-path="url(#c)"><rect width="10" height="10"/><text x="50" y="50">Hi</text></g>
        </svg>
        """)
        let builder = LayerTree.Builder(svg: svg)
        XCTAssertNil(builder.makeBoundingBox(for: svg.childElements[0]))
        let layer = builder.makeLayer()
        let masked = try XCTUnwrap(findLayer(in: layer) { $0.mask != nil })
        XCTAssertNil(findLayer(in: try XCTUnwrap(masked.mask)) { !$0.clip.isEmpty })
        XCTAssertNil(findLayer(in: layer) { !$0.clip.isEmpty })
    }

    func testMoveOnlyPathDoesNotCollapseGroupBoundingBox() throws {
        let c = try commands("""
        <clipPath id="c" clipPathUnits="objectBoundingBox"><rect width="0.5" height="1"/></clipPath>
        <g clip-path="url(#c)">
          <rect width="40" height="40"/>
          <path d="M 5 5" transform="scale(2)"/>
        </g>
        """)
        assertRect(clips(c).first?.bounds, 0, 0, 20, 40)
    }

    // MARK: - helpers

    func testBoundingBoxOfUseFanOutStaysBounded() throws {
        // 4 uses per level over 12 levels is 4^12 walks: measuring gives up instead and the box is unknown
        var defs = ##"<g id="l12"><rect width="1" height="1"/></g>"##
        for level in stride(from: 11, through: 0, by: -1) {
            defs += ##"<g id="l\##(level)">"## + String(repeating: ##"<use xlink:href="#l\##(level + 1)"/>"##, count: 4) + "</g>"
        }
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100" height="100">
        <defs>\(defs)</defs><use id="u" xlink:href="#l0"/>
        </svg>
        """)
        let builder = LayerTree.Builder(svg: svg)
        let use = try XCTUnwrap(svg.firstGraphicsElement(with: "u"))
        XCTAssertNil(builder.makeBoundingBox(for: use))
        XCTAssertEqual(builder.measurement.steps, LayerTree.Builder.MeasurementBudget.maxSteps)
    }

    func testClipPathChainFitsASmallSecondaryThreadStack() throws {
        // each nested clip-path costs native stack: the chain is cut at ReferenceGuard.maxDepth
        let chain = (0..<2_000).map {
            ##"<clipPath id="c\##($0)" clip-path="url(#c\##($0 + 1))"><rect width="90" height="90"/></clipPath>"##
        }.joined()
        nonisolated(unsafe) let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <defs>\(chain)</defs><rect width="50" height="50" clip-path="url(#c0)"/>
        </svg>
        """)
        nonisolated(unsafe) var result = [Command]()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            let layer = LayerTree.Builder(svg: svg).makeLayer()
            let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
            result = generator.renderCommands(for: layer, colorConverter: .default)
            done.signal()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        XCTAssertEqual(done.wait(timeout: .now() + 30), .success)
        XCTAssertFalse(fills(result).isEmpty)
    }

    private func findLayer(in layer: LayerTree.Layer, where predicate: (LayerTree.Layer) -> Bool) -> LayerTree.Layer? {
        if predicate(layer) { return layer }
        for case let .layer(child) in layer.contents {
            if let found = findLayer(in: child, where: predicate) { return found }
        }
        return nil
    }

    private func allContents(of layer: LayerTree.Layer) -> [LayerTree.Layer.Contents] {
        layer.contents.flatMap { c -> [LayerTree.Layer.Contents] in
            if case let .layer(child) = c { return allContents(of: child) }
            return [c]
        }
    }
}
