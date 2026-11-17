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

import Foundation
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
    func root_em_ex_dimensions_resolve_against_font_size() {
        let ex = #"<svg xmlns="http://www.w3.org/2000/svg" width="2ex" height="1ex"><rect width="5" height="5"/></svg>"#
        let em = #"<svg xmlns="http://www.w3.org/2000/svg" width="2em" height="1em"><rect width="5" height="5"/></svg>"#
        let px = #"<svg xmlns="http://www.w3.org/2000/svg" width="2px" height="1px"><rect width="5" height="5"/></svg>"#

        let exSVG = SVG(data: Data(ex.utf8))
        let emSVG = SVG(data: Data(em.utf8))
        let pxSVG = SVG(data: Data(px.utf8))

        // SVG 1.1 §7.10: 1em is the initial 16px font-size, 1ex half of it
        #expect(exSVG?.size == CGSize(width: 16, height: 8))
        #expect(emSVG?.size == CGSize(width: 32, height: 16))
        #expect(pxSVG?.size == CGSize(width: 2, height: 1))
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

// Hostile documents must return nil or draw nothing, never trap or recurse forever.
// A trap ends the whole test process, so each document has its own test.
struct SVGHostileTests {

    private static let head = "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""

    /// The steps of `SVG(data:)` (parse, layer tree, commands) without CoreGraphics, so these run on every platform.
    private func load(_ xml: String) -> [RendererCommand<LayerTreeProvider.Types>]? {
        guard let svg = try? DOM.SVG.parse(data: Data(xml.utf8)) else { return nil }
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }

    @Test
    func hugeWidthDoesNotTrap() {
        #expect(load("\(Self.head) width=\"1e30\" height=\"1\"><rect width=\"1\" height=\"1\"/></svg>") == nil)
    }

    @Test
    func hugeViewBoxDoesNotTrap() {
        #expect(load("\(Self.head) viewBox=\"0 0 1e999 1\"><rect width=\"1\" height=\"1\"/></svg>") == nil)
    }

    @Test
    func hugeStyleLengthDoesNotTrap() {
        #expect(load("\(Self.head)><style>svg { width: 1e30px }</style></svg>") == nil)
    }

    @Test
    func hugeEntityLengthDoesNotTrap() {
        #expect(load("<!DOCTYPE svg [<!ENTITY n \"1e30\">]>\(Self.head) width=\"&n;\" height=\"&n;\"/>") == nil)
    }

    @Test
    func useCycleDoesNotRecurse() {
        #expect(load("\(Self.head) width=\"9\" height=\"9\"><g id=\"a\"><use xlink:href=\"#a\"/></g></svg>") != nil)
    }

    @Test
    func mutualUseCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><g id=\"a\"><use href=\"#b\"/></g><g id=\"b\"><use href=\"#a\"/></g><use href=\"#a\"/></svg>"
            ) != nil
        )
    }

    @Test
    func patternUseCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><pattern id=\"p\" width=\"2\" height=\"2\"><use href=\"#r\"/></pattern><rect id=\"r\" width=\"9\" height=\"9\" fill=\"url(#p)\"/><use href=\"#r\"/></svg>"
            ) != nil
        )
    }

    @Test
    func useGradientCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><g id=\"a\"><use href=\"#b\"/></g><g id=\"b\" fill=\"url(#a)\"/></svg>"
            ) != nil
        )
    }

    @Test
    func useExternalFileCycleDoesNotRecurse() {
        #expect(
            load("\(Self.head) width=\"9\" height=\"9\"><g id=\"a\"><use xlink:href=\"p.svg#a\"/></g></svg>") != nil
        )
    }

    @Test
    func maskCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><mask id=\"m\"><rect width=\"5\" height=\"5\" mask=\"url(#m)\"/></mask><rect width=\"9\" height=\"9\" mask=\"url(#m)\"/></svg>"
            ) != nil
        )
    }

    @Test
    func maskPercentEncodedCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><mask id=\"m\"><rect width=\"5\" height=\"5\" mask=\"url(#%6d)\"/></mask><rect width=\"9\" height=\"9\" mask=\"url(#m)\"/></svg>"
            ) != nil
        )
    }

    @Test
    func clipPathCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><clipPath id=\"c\"><rect width=\"5\" height=\"5\" clip-path=\"url(#c)\"/></clipPath><rect width=\"9\" height=\"9\" clip-path=\"url(#c)\"/></svg>"
            ) != nil
        )
    }

    @Test
    func patternCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><pattern id=\"p\" width=\"2\" height=\"2\"><rect width=\"1\" height=\"1\" fill=\"url(#p)\"/></pattern><rect width=\"9\" height=\"9\" fill=\"url(#p)\"/></svg>"
            ) != nil
        )
    }

    @Test
    func markerCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><marker id=\"m\"><path d=\"M0 0L1 1\" marker-end=\"url(#m)\"/></marker><path d=\"M0 0L5 5\" marker-end=\"url(#m)\"/></svg>"
            ) != nil
        )
    }

    /// Level n is a group that uses level n - 1 `fanOut` times: `fanOut ^ depth` rects from a tiny file.
    private func fanOut(depth: Int, fanOut: Int) -> String {
        var defs = #"<rect id="l0" width="1" height="1"/>"#
        for level in 1...depth {
            let uses = String(repeating: ##"<use href="#l\##(level - 1)"/>"##, count: fanOut)
            defs += #"<g id="l\#(level)">\#(uses)</g>"#
        }
        return "\(Self.head) width=\"9\" height=\"9\"><defs>\(defs)</defs><use href=\"#l\(depth)\"/></svg>"
    }

    private func fillCount(_ commands: [RendererCommand<LayerTreeProvider.Types>]) -> Int {
        commands.filter { if case .fill = $0 { return true } else { return false } }.count
    }

    @Test
    func useFanOutIsBounded() throws {
        // 4^9 = 262,144 rects without a budget
        let svg = try #require(load(fanOut(depth: 9, fanOut: 4)))
        #expect(fillCount(svg) <= LayerTree.Builder.maxReferences)
    }

    @Test
    func largeUseFanOutStillLoads() {
        // 4^14 = 268 million rects without a budget
        #expect(load(fanOut(depth: 14, fanOut: 4)) != nil)
    }

    @Test
    func deepUseChainIsCapped() throws {
        let shallow = try #require(load(fanOut(depth: 10, fanOut: 1)))
        #expect(fillCount(shallow) == 1)
        let deep = try #require(load(fanOut(depth: 30, fanOut: 1)))
        #expect(fillCount(deep) == 0)
    }

    @Test
    func gradientHrefCycleDoesNotRecurse() {
        #expect(
            load(
                "\(Self.head) width=\"9\" height=\"9\"><linearGradient id=\"a\" href=\"#b\"/><linearGradient id=\"b\" href=\"#a\"/><rect width=\"9\" height=\"9\" fill=\"url(#a)\"/></svg>"
            ) != nil
        )
    }
}
