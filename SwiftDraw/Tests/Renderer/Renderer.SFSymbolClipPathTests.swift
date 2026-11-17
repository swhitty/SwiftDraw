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

import Foundation
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

#if canImport(CoreGraphics)
struct RendererSFSymbolClipPathTests {

    // MARK: - Issue #37 reproduction

    /// The exact SVG from the GitHub issue used as the reproducer for the missing clip-path
    /// support warning. Pre-fix this rendered nothing and emitted "clip-path unsupported".
    /// Post-fix it must produce the baked intersection (the clipping circle).
    @Test func issue37RectClippedByCircleProducesIntersectedPath() throws {
        let svg = try DOM.SVG.parse(
            #"""
            <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <clipPath id="clip1">
                  <circle cx="50" cy="50" r="30"/>
                </clipPath>
              </defs>
              <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#clip1)"/>
            </svg>
            """#
        )

        let template = try SFSymbolTemplate.parse(SFSymbolRenderer.render(svg: svg))

        #expect(!template.regular.contents.paths.isEmpty)
        #expect(!template.ultralight.contents.paths.isEmpty)
        #expect(!template.black.contents.paths.isEmpty)
    }

    // MARK: - Clip shape coverage (asserted on raw symbol paths in user space)

    @Test(
        arguments: [
            // 100x100 rect ∩ rect(20,20,60,60) = rect(20,20,60,60)
            ("clip-rect.svg", .init(x: 20, y: 20, width: 60, height: 60), 0.01),
            // 100x100 rect ∩ circle(50,50,r=30) = circle(50,50,r=30) → bounds(20,20,60,60)
            ("clip-circle.svg", .init(x: 20, y: 20, width: 60, height: 60), 0.5),
            // 100x100 rect ∩ ellipse(cx=50,cy=50,rx=40,ry=20) = ellipse → bounds(10,30,80,40)
            ("clip-ellipse.svg", .init(x: 10, y: 30, width: 80, height: 40), 0.5),
            // Triangle(50,10)-(90,90)-(10,90) → bounds(10,10,80,80)
            ("clip-polygon.svg", .init(x: 10, y: 10, width: 80, height: 80), 0.5),
            ("clip-path-element.svg", .init(x: 20, y: 20, width: 60, height: 60), 0.5),
            // Two overlapping circles centered at (35,50) and (65,50) with r=20, unioned.
            // Union extents: x ∈ [15,85], y ∈ [30,70]
            ("clip-multi-shape.svg", .init(x: 15, y: 30, width: 70, height: 40), 0.5),
            // Outer 80x80 with inner 40x40 hole using evenodd → bounds remain 10,10,80,80
            ("clip-rule-evenodd.svg", .init(x: 10, y: 10, width: 80, height: 80), 0.5),
            // rect(20,20,60,60) clipped by bbox-relative rect (0.25,0.25,0.5,0.5)
            // → user-space rect (35,35,30,30)
            ("clip-units-bbox.svg", .init(x: 35, y: 35, width: 30, height: 30), 0.5),
            // Clip fully contains the shape, so it keeps its original bounds
            ("clip-contains.svg", .init(x: 20, y: 20, width: 60, height: 60), 0.5),
            // Clip child rect(0,0,40,40) with transform translate(30,30) → effective (30,30,40,40)
            ("clip-transform-child.svg", .init(x: 30, y: 30, width: 40, height: 40), 0.5),
            // 100x100 rect drawn with translate(50,50), clipped by circle(0,0,r=30) in local space.
            // Post-transform clip is a circle at (50,50) with r=30 → bounds (20,20,60,60)
            ("clip-transformed-element.svg", .init(x: 20, y: 20, width: 60, height: 60), 0.5),
        ] as [(String, LayerTree.Rect, LayerTree.Float)]
    )
    func clipIntersectionBounds(resource: String, expected: LayerTree.Rect, tolerance: LayerTree.Float) throws {
        let paths = try makeSymbolPaths(forResource: resource)
        try #require(paths.count == 1)
        expectBounds(paths[0].path.bounds, equal: expected, tolerance: tolerance)
    }

    @Test func clipOnGroupAppliesToAllChildren() throws {
        let paths = try makeSymbolPaths(forResource: "clip-group.svg")
        // Two rects in a clipped group; each gets independently intersected with the rect clip.
        // Each result fits inside (20,20,60,60).
        #expect(paths.count > 0)
        for sp in paths {
            let b = sp.path.bounds
            #expect(b.minX >= 19.5)
            #expect(b.maxX <= 80.5)
            #expect(b.minY >= 19.5)
            #expect(b.maxY <= 80.5)
        }
    }

    @Test func clipFullyOutsideShapeDropsPath() throws {
        let paths = try makeSymbolPaths(forResource: "clip-outside.svg")
        #expect(paths.isEmpty)
    }

    // MARK: - Full pipeline smoke (renders to SF Symbol template)

    @Test func fullPipelineClipCircleEmitsThreeWeightVariants() throws {
        let url = try Bundle.test.url(forResource: "clip-circle.svg")
        let template = try SFSymbolTemplate.parse(SFSymbolRenderer.render(fileURL: url))
        #expect(template.regular.contents.paths.count == 1)
        #expect(template.ultralight.contents.paths.count == 1)
        #expect(template.black.contents.paths.count == 1)
    }

    @Test func fullPipelineClipFullyOutsideThrowsNoValidContent() throws {
        let url = try Bundle.test.url(forResource: "clip-outside.svg")
        #expect(throws: (any Error).self) {
            try SFSymbolRenderer.render(fileURL: url)
        }
    }

    // MARK: - Layer-level coverage

    @Test func builderSetsClipUnitsUserSpaceOnUseByDefault() throws {
        let svg = try DOM.SVG.parse(
            #"""
            <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <clipPath id="d"><rect x="0" y="0" width="5" height="5"/></clipPath>
              </defs>
              <rect x="0" y="0" width="10" height="10" fill="black" clip-path="url(#d)"/>
            </svg>
            """#
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = try #require(firstClippedLayer(in: layer))
        #expect(clipped.clipUnits == .userSpaceOnUse)
    }

    // MARK: - Helpers

    private func makeSymbolPaths(forResource named: String) throws -> [SFSymbolRenderer.SymbolPath] {
        let url = try Bundle.test.url(forResource: named)
        let svg = try DOM.SVG.parse(fileURL: url)
        return SFSymbolRenderer.getPaths(for: svg) ?? []
    }

    private func expectBounds(
        _ actual: LayerTree.Rect,
        equal expected: LayerTree.Rect,
        tolerance: LayerTree.Float,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            actual.minX.isApproximately(expected.minX, tolerance: tolerance),
            "minX",
            sourceLocation: sourceLocation
        )
        #expect(
            actual.minY.isApproximately(expected.minY, tolerance: tolerance),
            "minY",
            sourceLocation: sourceLocation
        )
        #expect(
            actual.width.isApproximately(expected.width, tolerance: tolerance),
            "width",
            sourceLocation: sourceLocation
        )
        #expect(
            actual.height.isApproximately(expected.height, tolerance: tolerance),
            "height",
            sourceLocation: sourceLocation
        )
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
    static func parse(_ text: String, filename: String = #filePath) throws -> DOM.SVG {
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
