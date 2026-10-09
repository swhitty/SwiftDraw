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

/// SD16: visibility and cascade follow-ups of SD7 and SD8 (SVG 1.1 §11.6.2, §14.3.5, §7.11).
final class LayerTreeVisibilityCascadeTests: XCTestCase {

    func testHiddenLeafWithFilterPaintsNothing() throws {
        let layer = try makeLayer("""
        <filter id="f"><feFlood flood-color="red"/></filter>
        <rect width="10" height="10" visibility="hidden" filter="url(#f)" opacity="0.5"/>
        """)
        XCTAssertNil(findLayer(in: layer) { !$0.filters.isEmpty })
        XCTAssertTrue(allContents(of: layer).isEmpty)
    }

    func testVisibleChildOfHiddenGroupStillPaints() throws {
        let layer = try makeLayer("""
        <g visibility="hidden"><rect width="10" height="10"/><rect width="5" height="5" visibility="visible"/></g>
        """)
        XCTAssertEqual(allContents(of: layer).count, 1)
    }

    func testRootWithDisplayNoneHasNoViewBoxTransform() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" style="display:none"><rect width="10" height="10"/></svg>
        """)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        XCTAssertTrue(layer.transform.isEmpty)
        XCTAssertTrue(layer.contents.isEmpty)
    }

    func testHiddenClipPathHidesItsChildrenUnlessTheySayVisible() throws {
        let hidden = try makeLayer("""
        <clipPath id="c" visibility="hidden"><rect width="5" height="5"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """)
        // nothing contributes: the clip is the empty shape, which clips everything
        XCTAssertEqual(findLayer(in: hidden) { !$0.clip.isEmpty }?.clip, [.empty])

        let shown = try makeLayer("""
        <clipPath id="c" visibility="hidden"><rect width="5" height="5"/><rect width="2" height="2" visibility="visible"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c)"/>
        """)
        XCTAssertEqual(findLayer(in: shown) { !$0.clip.isEmpty }?.clip.count, 1)
        XCTAssertNotEqual(findLayer(in: shown) { !$0.clip.isEmpty }?.clip, [.empty])
    }

    func testClipRuleSetOnClipPathByCSS() throws {
        let layer = try makeLayer("""
        <style>.c { clip-rule: evenodd }</style>
        <clipPath id="c1" class="c"><rect width="5" height="5"/></clipPath>
        <rect width="10" height="10" clip-path="url(#c1)"/>
        """)
        XCTAssertEqual(findLayer(in: layer) { !$0.clip.isEmpty }?.clipRule, .evenodd)
    }

    func testClipPathOnAClipPathChildClipsThatChild() throws {
        let layer = try makeLayer("""
        <clipPath id="a"><rect width="10" height="10"/></clipPath>
        <clipPath id="c"><rect width="20" height="20" clip-path="url(#a)"/></clipPath>
        <rect width="20" height="20" clip-path="url(#c)"/>
        """)
        // one clipping path cannot express it: it becomes an alpha mask whose member carries its own clip
        let masked = try XCTUnwrap(findLayer(in: layer) { $0.mask != nil })
        XCTAssertTrue(masked.maskIsClip)
        let mask = try XCTUnwrap(masked.mask)
        XCTAssertNotNil(findLayer(in: mask) { !$0.clip.isEmpty })
    }

    func testBoundingBoxReadsDisplayAndTransformFromTheCascade() throws {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
        <style>.h { display: none } .t { transform: translate(50, 0) }</style>
        <g id="g"><rect width="10" height="10"/><rect class="h" width="100" height="100"/><rect class="t" width="10" height="10"/></g>
        </svg>
        """)
        let box = try XCTUnwrap(LayerTree.Builder(svg: svg).makeBoundingBox(for: svg.childElements[0]))
        XCTAssertEqual(box, LayerTree.Rect(x: 0, y: 0, width: 60, height: 10))
    }

    func testHiddenGeometryStaysInTheBoundingBox() throws {
        // SVG 2 keeps `visibility: hidden` geometry in the bounding box
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
        <g id="g"><rect width="10" height="10"/><rect x="40" width="10" height="10" visibility="hidden"/></g>
        </svg>
        """)
        let box = try XCTUnwrap(LayerTree.Builder(svg: svg).makeBoundingBox(for: svg.childElements[0]))
        XCTAssertEqual(box, LayerTree.Rect(x: 0, y: 0, width: 50, height: 10))
    }

    func testUnionBeyondTheFloatRangeIsNotKnown() {
        let big = LayerTree.Float.greatestFiniteMagnitude * 0.75
        let a = LayerTree.Rect(x: -big, y: 0, width: 1, height: 1)
        let b = LayerTree.Rect(x: big, y: 0, width: 1, height: 1)
        guard case .empty = LayerTree.Builder.Bounds(a.union(b)) else { return XCTFail("expected empty") }
    }

    func testLayerEqualityAndHashSeeMaskIsClip() {
        let a = LayerTree.Layer()
        let b = LayerTree.Layer()
        XCTAssertEqual(a, b)
        b.maskIsClip = true
        XCTAssertNotEqual(a, b)
    }

    func testGroupWithTextKeepsTheTextWhenTheBoundingBoxIsUnknown() throws {
        let layer = try makeLayer("""
        <mask id="m"><rect width="100" height="100" fill="white"/></mask>
        <g mask="url(#m)"><rect width="10" height="10"/><text x="50" y="50">Hi</text></g>
        """)
        XCTAssertTrue(allContents(of: layer).contains { if case .text = $0 { return true }; return false })
    }

    func testFilterAndMaskTypeClipBothSurvive() throws {
        let layer = try makeLayer("""
        <filter id="f"><feGaussianBlur stdDeviation="0.5"/></filter>
        <clipPath id="c"><rect width="6" height="16" clip-rule="evenodd"/><rect x="10" width="6" height="16"/></clipPath>
        <rect width="16" height="16" filter="url(#f)" clip-path="url(#c)"/>
        """)
        let filtered = try XCTUnwrap(findLayer(in: layer) { !$0.filters.isEmpty })
        XCTAssertTrue(filtered.maskIsClip)
        XCTAssertNotNil(filtered.mask)
    }

    // MARK: helpers

    private func makeLayer(_ body: String) throws -> LayerTree.Layer {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\(body)</svg>
        """)
        return LayerTree.Builder(svg: svg).makeLayer()
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
