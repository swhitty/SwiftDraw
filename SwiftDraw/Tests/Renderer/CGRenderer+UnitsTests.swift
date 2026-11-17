//
//  CGRenderer+UnitsTests.swift
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

@testable import SwiftDrawDOM
@testable import SwiftDraw
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import CoreGraphics

// SD13 — SVG 1.1 §7.10: units, percentages and fractional root sizes, in pixels
struct CGRendererUnitsTests {

    private func render(_ xml: String, pixelsWide: Int, pixelsHigh: Int) throws -> ImageRenderer {
        let svg = SVG(dom: try DOM.SVG.parse(xml: xml), options: .default)
        let renderer = ImageRenderer(pixelsWide: pixelsWide, pixelsHigh: pixelsHigh)
        renderer.renderer.perform(svg.commands)
        return renderer
    }

    @Test
    func percentageWidthFillsHalfTheViewport() throws {
        // `width="50%"` used to be 50 user units
        let renderer = try render(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
            <rect x="50%" width="50%" height="100%" fill="red"/></svg>
            """,
            pixelsWide: 200,
            pixelsHigh: 100
        )

        #expect(!renderer.isSVGRed(x: 50, y: 50))
        #expect(!renderer.isSVGRed(x: 98, y: 50))
        #expect(renderer.isSVGRed(x: 102, y: 50))
        #expect(renderer.isSVGRed(x: 195, y: 50))
    }

    @Test
    func fractionalRootSizeIsNotLetterboxed() throws {
        // truncated to 150, the 150.9-wide viewBox met at x0.994 and left a 0.3px band top and bottom
        let renderer = try render(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="150.9" height="100" viewBox="0 0 150.9 100">
            <rect width="150.9" height="100" fill="red"/></svg>
            """,
            pixelsWide: 151,
            pixelsHigh: 100
        )

        #expect(renderer.isSVGRed(x: 75, y: 0))
        #expect(renderer.isSVGRed(x: 75, y: 99))
    }

    @Test
    func rootWithOnlyWidthKeepsTheViewBoxRatio() throws {
        // 200x100 like the browsers, not 200x50 with the viewBox centred in it
        let renderer = try render(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="200" viewBox="0 0 100 50">
            <rect width="100" height="50" fill="red"/></svg>
            """,
            pixelsWide: 200,
            pixelsHigh: 100
        )

        #expect(renderer.isSVGRed(x: 5, y: 5))
        #expect(renderer.isSVGRed(x: 195, y: 95))
    }

    @Test
    func millimetresAndEmResolveToPixels() throws {
        // 25.4mm = 96px wide; 3em = 48px high at the initial 16px font-size
        let renderer = try render(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="48">
            <rect width="25.4mm" height="3em" fill="red"/></svg>
            """,
            pixelsWide: 100,
            pixelsHigh: 48
        )

        #expect(renderer.isSVGRed(x: 94, y: 2))
        #expect(renderer.isSVGRed(x: 94, y: 45))
        #expect(!renderer.isSVGRed(x: 98, y: 24))
    }
}

private extension ImageRenderer {

    /// An SVG `red` fill reads back as pure (1, 0, 0).
    func isSVGRed(x: Int, y: Int) -> Bool {
        guard let cg = getColor(x: x, y: y),
            let c = NSColor(cgColor: cg)?.usingColorSpace(.deviceRGB)
        else { return false }
        return c.redComponent > 0.99 && c.greenComponent < 0.01 && c.blueComponent < 0.01 && c.alphaComponent > 0.99
    }
}

#endif
