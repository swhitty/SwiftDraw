//
//  Renderer.SFSymbolClipMaskTests.swift
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
import SwiftDrawDOM
import Testing

/// SD8: clips reaching the SF Symbol renderer.
struct SFSymbolClipMaskTests {

    /// objectBoundingBox units are resolved by the Builder: the clip reaches the renderers in user space.
    @Test
    func builderResolvesObjectBoundingBoxClipUnits() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="10" height="10" xmlns="http://www.w3.org/2000/svg">
                  <defs>
                    <clipPath id="bb" clipPathUnits="objectBoundingBox">
                      <rect x="0" y="0" width="1" height="1"/>
                    </clipPath>
                  </defs>
                  <rect x="0" y="0" width="10" height="10" fill="black" clip-path="url(#bb)"/>
                </svg>
                """#
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let clipped = try #require(firstClippedLayer(in: layer))
        #expect(clipped.clipUnits == .userSpaceOnUse)
        #expect(clipped.clip.first?.transform == LayerTree.Transform.Matrix(a: 10, b: 0, c: 0, d: 10, tx: 0, ty: 0))
    }

    #if canImport(CoreGraphics)
    /// A clip drawn as a mask (here mixed clip-rules) keeps its content, unclipped, in symbol export.
    @Test
    func maskTypeClipKeepsContentUnclipped() throws {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                  <clipPath id="c">
                    <rect width="10" height="10" clip-rule="evenodd"/>
                    <rect x="20" width="10" height="10"/>
                  </clipPath>
                  <rect x="0" y="0" width="100" height="100" fill="black" clip-path="url(#c)"/>
                </svg>
                """#
        )
        let paths = SFSymbolRenderer.getPaths(for: svg) ?? []
        try #require(paths.count == 1)
        let bounds = paths[0].path.bounds
        #expect(abs(bounds.minX - 0) <= 0.5)
        #expect(abs(bounds.minY - 0) <= 0.5)
        #expect(abs(bounds.width - 100) <= 0.5)
        #expect(abs(bounds.height - 100) <= 0.5)
    }
    #endif

    private func firstClippedLayer(in layer: LayerTree.Layer) -> LayerTree.Layer? {
        if !layer.clip.isEmpty { return layer }
        for case let .layer(inner) in layer.contents {
            if let hit = firstClippedLayer(in: inner) { return hit }
        }
        return nil
    }
}
