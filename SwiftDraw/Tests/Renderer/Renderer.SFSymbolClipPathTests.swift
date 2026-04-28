//
//  Renderer.SFSymbolClipPathTests.swift
//  SwiftDraw
//
//  Created by SwiftDraw contributors
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

import SwiftDrawDOM
import XCTest
@testable import SwiftDraw

#if canImport(CoreGraphics)
final class RendererSFSymbolClipPathTests: XCTestCase {

    // MARK: - Issue #37 reproduction

    /// The exact SVG from the GitHub issue used as the reproducer for the missing clip-path
    /// support warning. Pre-fix this rendered nothing and emitted "clip-path unsupported".
    /// Post-fix it must produce the baked intersection (the clipping circle).
    func testIssue37_minimalRectClippedByCircle_producesIntersectedPath() throws {
        let svg = try DOM.SVG.parse(#"""
        <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <clipPath id="clip1">
              <circle cx="50" cy="50" r="30"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#clip1)"/>
        </svg>
        """#)

        let template = try SFSymbolTemplate.parse(SFSymbolRenderer.render(svg: svg))

        XCTAssertFalse(template.regular.contents.paths.isEmpty)
        XCTAssertFalse(template.ultralight.contents.paths.isEmpty)
        XCTAssertFalse(template.black.contents.paths.isEmpty)
    }

    // MARK: - Clip shape coverage (asserted on raw symbol paths in user space)

    func testClipRect_intersectionIsClippingRect() throws {
        let paths = try makeSymbolPaths(forResource: "clip-rect.svg")
        XCTAssertEqual(paths.count, 1)
        // 100x100 rect ∩ rect(20,20,60,60) = rect(20,20,60,60)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 20, y: 20, width: 60, height: 60))
    }

    func testClipCircle_intersectionIsClippingCircle() throws {
        let paths = try makeSymbolPaths(forResource: "clip-circle.svg")
        XCTAssertEqual(paths.count, 1)
        // 100x100 rect ∩ circle(50,50,r=30) = circle(50,50,r=30) → bounds(20,20,60,60)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 20, y: 20, width: 60, height: 60),
                     accuracy: 0.5)
    }

    func testClipEllipse_intersectionIsClippingEllipse() throws {
        let paths = try makeSymbolPaths(forResource: "clip-ellipse.svg")
        XCTAssertEqual(paths.count, 1)
        // 100x100 rect ∩ ellipse(cx=50,cy=50,rx=40,ry=20) = ellipse → bounds(10,30,80,40)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 10, y: 30, width: 80, height: 40),
                     accuracy: 0.5)
    }

    func testClipPolygon_intersectionMatchesPolygon() throws {
        let paths = try makeSymbolPaths(forResource: "clip-polygon.svg")
        XCTAssertEqual(paths.count, 1)
        // Triangle(50,10)-(90,90)-(10,90) → bounds(10,10,80,80)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 10, y: 10, width: 80, height: 80),
                     accuracy: 0.5)
    }

    func testClipPathElement_intersectionMatchesPath() throws {
        let paths = try makeSymbolPaths(forResource: "clip-path-element.svg")
        XCTAssertEqual(paths.count, 1)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 20, y: 20, width: 60, height: 60),
                     accuracy: 0.5)
    }

    func testClipMultiShape_unionsAllChildren() throws {
        let paths = try makeSymbolPaths(forResource: "clip-multi-shape.svg")
        XCTAssertEqual(paths.count, 1)
        // Two overlapping circles centered at (35,50) and (65,50) with r=20.
        // Union extents: x ∈ [15,85], y ∈ [30,70]
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 15, y: 30, width: 70, height: 40),
                     accuracy: 0.5)
    }

    func testClipOnGroup_appliesToAllChildren() throws {
        let paths = try makeSymbolPaths(forResource: "clip-group.svg")
        // Two rects in a clipped group; each gets independently intersected with the rect clip.
        // Each result fits inside (20,20,60,60).
        XCTAssertGreaterThan(paths.count, 0)
        for sp in paths {
            let b = sp.path.bounds
            XCTAssertGreaterThanOrEqual(b.minX, 19.5)
            XCTAssertLessThanOrEqual(b.maxX, 80.5)
            XCTAssertGreaterThanOrEqual(b.minY, 19.5)
            XCTAssertLessThanOrEqual(b.maxY, 80.5)
        }
    }

    func testClipRuleEvenOdd_producesAnnulusBounds() throws {
        let paths = try makeSymbolPaths(forResource: "clip-rule-evenodd.svg")
        // Outer 80x80 with inner 40x40 hole using evenodd → bounds remain 10,10,80,80
        XCTAssertEqual(paths.count, 1)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 10, y: 10, width: 80, height: 80),
                     accuracy: 0.5)
    }

    func testClipUnitsObjectBoundingBox_appliesShapeRelativeCoords() throws {
        let paths = try makeSymbolPaths(forResource: "clip-units-bbox.svg")
        XCTAssertEqual(paths.count, 1)
        // rect(20,20,60,60) clipped by bbox-relative rect (0.25,0.25,0.5,0.5)
        // → user-space rect (35,35,30,30)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 35, y: 35, width: 30, height: 30),
                     accuracy: 0.5)
    }

    func testClipFullyContainsShape_keepsOriginalBounds() throws {
        let paths = try makeSymbolPaths(forResource: "clip-contains.svg")
        XCTAssertEqual(paths.count, 1)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 20, y: 20, width: 60, height: 60),
                     accuracy: 0.5)
    }

    func testClipFullyOutsideShape_dropsPath() throws {
        let paths = try makeSymbolPaths(forResource: "clip-outside.svg")
        XCTAssertEqual(paths.count, 0)
    }

    func testClipChildTransform_isApplied() throws {
        let paths = try makeSymbolPaths(forResource: "clip-transform-child.svg")
        XCTAssertEqual(paths.count, 1)
        // Clip child rect(0,0,40,40) with transform translate(30,30) → effective (30,30,40,40)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 30, y: 30, width: 40, height: 40),
                     accuracy: 0.5)
    }

    func testClipPropagatesThroughElementTransform() throws {
        let paths = try makeSymbolPaths(forResource: "clip-transformed-element.svg")
        XCTAssertEqual(paths.count, 1)
        // 100x100 rect drawn with translate(50,50), clipped by circle(0,0,r=30) in local space.
        // Post-transform clip is a circle at (50,50) with r=30 → bounds (20,20,60,60)
        assertBounds(paths[0].path.bounds,
                     equals: .init(x: 20, y: 20, width: 60, height: 60),
                     accuracy: 0.5)
    }

    // MARK: - Full pipeline smoke (renders to SF Symbol template)

    func testFullPipeline_clipCircle_emitsThreeWeightVariants() throws {
        let url = try Bundle.test.url(forResource: "clip-circle.svg")
        let template = try SFSymbolTemplate.parse(SFSymbolRenderer.render(fileURL: url))
        XCTAssertEqual(template.regular.contents.paths.count, 1)
        XCTAssertEqual(template.ultralight.contents.paths.count, 1)
        XCTAssertEqual(template.black.contents.paths.count, 1)
    }

    func testFullPipeline_clipFullyOutside_throwsNoValidContent() throws {
        let url = try Bundle.test.url(forResource: "clip-outside.svg")
        XCTAssertThrowsError(try SFSymbolRenderer.render(fileURL: url))
    }

    // MARK: - Layer-level coverage

    /// Independent smoke test: the layer's clipUnits propagates through Builder.
    func testBuilder_setsClipUnits_objectBoundingBox() throws {
        let svg = try DOM.SVG.parse(#"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <clipPath id="bb" clipPathUnits="objectBoundingBox">
              <rect x="0" y="0" width="1" height="1"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="10" height="10" fill="black" clip-path="url(#bb)"/>
        </svg>
        """#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = firstClippedLayer(in: layer)
        XCTAssertNotNil(clipped)
        XCTAssertEqual(clipped?.clipUnits, .objectBoundingBox)
    }

    func testBuilder_setsClipUnits_userSpaceOnUseByDefault() throws {
        let svg = try DOM.SVG.parse(#"""
        <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <clipPath id="d"><rect x="0" y="0" width="5" height="5"/></clipPath>
          </defs>
          <rect x="0" y="0" width="10" height="10" fill="black" clip-path="url(#d)"/>
        </svg>
        """#)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = firstClippedLayer(in: layer)
        XCTAssertNotNil(clipped)
        XCTAssertEqual(clipped?.clipUnits, .userSpaceOnUse)
    }

    // MARK: - Helpers

    private func makeSymbolPaths(forResource named: String) throws -> [SFSymbolRenderer.SymbolPath] {
        let url = try Bundle.test.url(forResource: named)
        let svg = try DOM.SVG.parse(fileURL: url)
        return SFSymbolRenderer.getPaths(for: svg) ?? []
    }

    private func assertBounds(_ actual: LayerTree.Rect,
                              equals expected: LayerTree.Rect,
                              accuracy: LayerTree.Float = 0.01,
                              file: StaticString = #file,
                              line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: accuracy, "minX", file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: accuracy, "minY", file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, "width", file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, "height", file: file, line: line)
    }

    private func firstClippedLayer(in layer: LayerTree.Layer) -> LayerTree.Layer? {
        if !layer.clip.isEmpty { return layer }
        for c in layer.contents {
            if case .layer(let inner) = c, let hit = firstClippedLayer(in: inner) {
                return hit
            }
        }
        return nil
    }
}
#endif

private extension DOM.SVG {
    static func parse(_ text: String, filename: String = #file) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: text.data(using: .utf8)!)
        let parser = XMLParser(options: [], filename: filename)
        return try parser.parseSVG(element)
    }
}

private extension SFSymbolRenderer {

    static func render(fileURL: URL) throws -> String {
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false
        )
        return try renderer.render(regular: fileURL, ultralight: nil, black: nil)
    }

    static func render(svg: DOM.SVG) throws -> String {
        let renderer = SFSymbolRenderer(
            size: .small,
            options: [],
            insets: .init(),
            insetsUltralight: .init(),
            insetsBlack: .init(),
            precision: 3,
            isLegacyInsets: false
        )
        return try renderer.render(default: svg, ultralight: nil, black: nil)
    }
}
