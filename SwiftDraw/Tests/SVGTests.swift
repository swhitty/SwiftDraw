//
//  SVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/11/18.
//  Copyright 2020 Simon Whitty
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
@testable import SwiftDraw
import Testing

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)
struct SVGTests {

    @Test
    func validSVGLoads() {
        #expect(SVG(named: "lines.svg", in: .test) != nil)
    }

    @Test
    func invalidSVGReturnsNil() {
        #expect(SVG(named: "invalids.svg", in: .test) == nil)
    }

    @Test
    func missingSVGReturnsNil() {
        #expect(SVG(named: "missing.svg", in: .test) == nil)
    }

    @Test
    func imageRasterizes() {
        let image = SVG.makeLines()
        let rendered = image.rasterize(scale: 1)
        #expect(rendered.size == image.size)
        #expect(throws: Never.self) {
            try image.pngData()
        }
        #expect(throws: Never.self) {
            try image.jpegData()
        }
        #expect(throws: Never.self) {
            try image.pdfData()
        }
    }

    @Test
    func shapesImageRasterizes() throws {
        let image = try #require(SVG(named: "shapes.svg", in: .test))
        #expect(throws: Never.self) {
            try image.pngData()
        }
        #expect(throws: Never.self) {
            try image.jpegData()
        }
        #expect(throws: Never.self) {
            try image.pdfData()
        }
    }

#if canImport(UIKit)
    @Test
    func rasterize() {
        let svg = SVG(named: "gradient-apple.svg", in: .test)!
            .sized(CGSize(width: 100, height: 100))
        let image = svg.rasterize(scale: 3)
        #expect(image.size == CGSize(width: 100, height: 100))
        #expect(image.scale == 3)

        let data = image.pngData()!
        let reloaded = UIImage(data: data)!
        #expect(reloaded.size == CGSize(width: 300, height: 300))
        #expect(reloaded.scale == 1)
    }
#endif

    @Test
    func size() {
        let image = SVG.makeLines()

        #expect(
            image.size == CGSize(width: 100, height: 100)
        )
        #expect(
            image.sized(CGSize(width: 200, height: 200)).size == CGSize(width: 200, height: 200)
        )

        var copy = image
        copy.size(CGSize(width: 20, height: 20))
        #expect(
            copy.size == CGSize(width: 20, height: 20)
        )
    }

    @Test
    func scale() {
        let image = SVG.makeLines()

        #expect(
            image.size == CGSize(width: 100, height: 100)
        )
        #expect(
            image.scaled(2).size == CGSize(width: 200, height: 200)
        )
        #expect(
            image.scaled(0.5).size == CGSize(width: 50, height: 50)
        )
        #expect(
            image.scaled(x: 2, y: 3).size == CGSize(width: 200, height: 300)
        )

        var copy = image
        copy.scale(5)
        #expect(
            copy.size == CGSize(width: 500, height: 500)
        )
    }

    @Test
    func translate() {
        let image = SVG.makeLines()

        #expect(
            image.size == CGSize(width: 100, height: 100)
        )
        #expect(
            image.translated(tx: 10, ty: 10).size == CGSize(width: 100, height: 100)
        )

        var copy = image
        copy.translate(tx: 50, ty: 50)
        #expect(
            copy.size == CGSize(width: 100, height: 100)
        )
    }

    @Test
    func expand() {
        let image = SVG.makeLines()

        #expect(
            image.size == CGSize(width: 100, height: 100)
        )
        #expect(
            image.expanded(top: 50, right: 30).size == CGSize(width: 130, height: 150)
        )

        var copy = image
        copy.expand(-10)
        #expect(
            copy.size == CGSize(width: 80, height: 80)
        )
    }

    @Test
    func hashable() {
        var images = Set<SVG>()
        let lines = SVG.makeLines()

        #expect(!images.contains(lines))

        images.insert(SVG.makeLines())
        #expect(images.contains(lines))

        let linesResized = lines.sized(CGSize(width: 10, height: 10))
        #expect(!images.contains(linesResized))

        images.remove(lines)
        #expect(!images.contains(SVG.makeLines()))
    }

    @Test
    func deepNestedSVG() async {
        let circle = DOM.Circle(cx: 50, cy: 50, r: 10)
        let dom = DOM.SVG(width: 50, height: 50)
        dom.childElements.append(DOM.Group.make(child: circle, nestedLevels: 500))

        _ = SVG(dom: dom, options: .default)
    }

    @Test
    func cache() {
        let cache = SVGGCache(totalCostLimit: 10 * 1024 * 1024)
        let svg = SVG.makeLines()
        let url = URL(fileURLWithPath: "/test/cached.svg")

        // Initially empty
        #expect(cache.svg(fileURL: url) == nil)

        // Store and retrieve
        cache.setSVG(svg, for: url)
        #expect(cache.svg(fileURL: url) != nil)

        // Different URL returns nil
        let otherURL = URL(fileURLWithPath: "/test/other.svg")
        #expect(cache.svg(fileURL: otherURL) == nil)
    }

    @Test
    func cacheSharedInstance() {
        let shared = SVGGCache.shared
        #expect(shared === SVGGCache.shared)
    }

    @Test
    func insets() {
        let zero = SVG.Insets.zero
        #expect(zero.top == 0)
        #expect(zero.left == 0)
        #expect(zero.bottom == 0)
        #expect(zero.right == 0)

        let custom = SVG.Insets(top: 10, left: 20, bottom: 30, right: 40)
        #expect(custom.top == 10)
        #expect(custom.left == 20)
        #expect(custom.bottom == 30)
        #expect(custom.right == 40)

        #expect(SVG.Insets.zero == SVG.Insets(top: 0, left: 0, bottom: 0, right: 0))
        #expect(SVG.Insets.zero != custom)
    }

    @Test
    func defaultCostLimit() {
        let limit = SVGGCache.defaultTotalCostLimit
        #expect(limit > 0)
    }
}

private extension SVG {

    static func makeLines() -> SVG {
        let svg = DOM.SVG(width: 100, height: 100)
        svg.childElements.append(DOM.Line(x1: 0, y1: 0, x2: 100, y2: 100))
        svg.childElements.append(DOM.Line(x1: 100, y1: 0, x2: 0, y2: 100))
        return SVG(dom: svg, options: .default)
    }
}
#endif
