//
//  PreserveAspectRatioRenderTests.swift
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
import Foundation
import Testing

/// preserveAspectRatio through the CGText code generator.
struct CGTextPreserveAspectRatioTests {

    @Test
    func rootSliceIsClippedToItsViewport() throws {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice"><rect width="100" height="100"/></svg>"#
        let code = try CGTextRenderer.render(data: Data(svg.utf8), options: .default, api: .uiKit, precision: 2)
        let lines = code.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // the 200x100 viewport is 100x50 in viewBox space after the 2x scale
        let scale = try #require(lines.firstIndex(of: "ctx.scaleBy(x: 2, y: 2)"))
        let clip = try #require(lines.firstIndex(where: { $0.hasSuffix("CGRect(x: 0, y: 0, width: 100, height: 50),") }))
        #expect(clip > scale)
        #expect(lines.contains("ctx.clip()"))
    }

    @Test
    func imageIsDroppedWithAWarningNotAnUndeclaredReference() throws {
        let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        let xml = """
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <image width="50" height="20" preserveAspectRatio="xMidYMid slice" xlink:href="data:image/png;base64,\(png)" />
        </svg>
        """
        let code = try CGTextRenderer.render(data: Data(xml.utf8), options: .default, api: .uiKit, precision: 2)
        #expect(!code.contains("ctx.draw(image"))
        #expect(code.contains("// warning: image dropped"))
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

/// preserveAspectRatio through the CoreGraphics renderer, checked by pixel.
struct CGPreserveAspectRatioTests {

    private func render(_ xml: String, pixelsWide: Int, pixelsHigh: Int) throws -> ImageRenderer {
        let svg = SVG(dom: try DOM.SVG.parse(xml: xml), options: .default)
        let renderer = ImageRenderer(pixelsWide: pixelsWide, pixelsHigh: pixelsHigh)
        renderer.renderer.perform(svg.commands)
        return renderer
    }

    @Test
    func letterboxesViewBox() throws {
        // 100x100 viewBox in a 200x100 viewport: xMidYMid meet centres it, leaving 50px bands either side
        let renderer = try render("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100">
        <rect width="100" height="100" fill="red"/></svg>
        """, pixelsWide: 200, pixelsHigh: 100)
        #expect(renderer.isSVGRed(x: 100, y: 50))
        #expect(renderer.isSVGRed(x: 55, y: 50))
        #expect(!renderer.isSVGRed(x: 45, y: 50))
        #expect(!renderer.isSVGRed(x: 155, y: 50))
    }

    @Test
    func sliceFillsViewport() throws {
        let renderer = try render("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice">
        <rect width="100" height="100" fill="red"/></svg>
        """, pixelsWide: 200, pixelsHigh: 100)
        #expect(renderer.isSVGRed(x: 5, y: 5))
        #expect(renderer.isSVGRed(x: 195, y: 95))
    }

    @Test
    func rootSliceDoesNotBleedOutsideItsViewport() throws {
        // drawn into a larger context, the overflow of a sliced viewBox is clipped to the 200x100 viewport
        let renderer = try render("""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="xMinYMin slice">
        <rect x="-50" y="-50" width="300" height="300" fill="red"/></svg>
        """, pixelsWide: 300, pixelsHigh: 200)
        // the context is not flipped, so the 200x100 viewport is the bottom half of the 300x200 bitmap (rows 100...199)
        #expect(renderer.isSVGRed(x: 100, y: 150))
        #expect(!renderer.isSVGRed(x: 250, y: 150))
        #expect(!renderer.isSVGRed(x: 100, y: 50))
    }
}

private extension ImageRenderer {

    /// An SVG `red` fill reads back as pure (1, 0, 0).
    func isSVGRed(x: Int, y: Int) -> Bool {
        guard let cg = getColor(x: x, y: y),
              let c = NSColor(cgColor: cg)?.usingColorSpace(.deviceRGB) else { return false }
        return c.redComponent > 0.99 && c.greenComponent < 0.01 && c.blueComponent < 0.01 && c.alphaComponent > 0.99
    }
}
#endif
