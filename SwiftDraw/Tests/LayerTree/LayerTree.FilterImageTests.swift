//
//  LayerTree.FilterImageTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

@testable import SwiftDrawDOM
@testable import SwiftDraw
import Foundation
import Testing

// Filter Effects 1 §9.15 feImage, with the cases of resvg's filters/feImage tests
struct LayerTreeFilterImageTests {

    // a 16×16 PNG, as in resvg's tests
    static let png =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAAB3RJTUUH4gMLDwAjrsLbtwAAAAlwSFlzAAAuIwAALiMBeKU/dgAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAGUExURQAA/xjQP14JpdQAAAABYktHRACIBR1IAAAAFklEQVR42mMAgvp/IJTAhgdB1ADVAgDvdAnxN1Ib1gAAAABJRU5ErkJggg=="

    @Test
    func parsesImage() throws {
        let svg = try DOM.SVG.parse(
            xml: ##"""
                <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
                    <filter id="a"><feImage xlink:href="#r" preserveAspectRatio="xMinYMax slice" in="SourceAlpha"/></filter>
                    <filter id="b" image-rendering="optimizeSpeed"><feImage href="#r"/><feImage href="#r" style="image-rendering: auto"/></filter>
                    <filter id="c"><feImage href=""/><feImage/><feImage image-rendering="pixelated"/></filter>
                </svg>
                """##
        )
        let a = try #require(svg.defs.filters.first { $0.id == "a" })
        #expect(
            a.effects == [
                .image(
                    DOM.Filter.Image(
                        href: URL(string: "#r"),
                        preserveAspectRatio: .init(align: .xMinYMax, meetOrSlice: .slice)
                    )
                )
            ]
        )
        // no input
        #expect(a.primitives[0].inputs.isEmpty)

        let b = try #require(svg.defs.filters.first { $0.id == "b" })
        #expect(
            b.effects == [
                .image(DOM.Filter.Image(href: URL(string: "#r"), isPixelated: true)),
                .image(DOM.Filter.Image(href: URL(string: "#r"), isPixelated: false)),
            ]
        )

        let c = try #require(svg.defs.filters.first { $0.id == "c" })
        #expect(
            c.effects == [
                .image(DOM.Filter.Image()),
                .image(DOM.Filter.Image()),
                .image(DOM.Filter.Image(isPixelated: true)),
            ]
        )
    }

    // link-to-an-element: drawn in user space, offset to the subregion's origin (the filter region here)
    @Test
    func elementIsOffsetToTheSubregion() throws {
        let filter = try makeFilterLayer(##"<feImage href="#r"/>"##)
        let image = try #require(filter.image)
        #expect(filter.primitives[0].subregion == filter.region)
        #expect(image.layer.transform == [.translate(tx: 4, ty: 4)])
        #expect(image.layer.bounds == LayerTree.Rect(x: 40, y: 40, width: 120, height: 120))
        #expect(!image.isPixelated)
    }

    // with-x-y, with-x-y-and-protruding-subregion: x and y move the element, width and height do not scale it;
    // the subregion is clipped to the filter region
    @Test(
        arguments: [
            (
                ##"x="50" y="50""##, LayerTree.Rect(x: 86, y: 86, width: 120, height: 120),
                LayerTree.Rect(x: 50, y: 50, width: 146, height: 146)
            ),
            (
                ##"x="50" y="50" width="30" height="30""##, LayerTree.Rect(x: 86, y: 86, width: 120, height: 120),
                LayerTree.Rect(x: 50, y: 50, width: 30, height: 30)
            ),
            (
                ##"x="-20" y="0""##, LayerTree.Rect(x: 16, y: 36, width: 120, height: 120),
                LayerTree.Rect(x: 4, y: 4, width: 168, height: 188)
            ),
        ] as [(String, LayerTree.Rect, LayerTree.Rect)]
    )
    func elementSubregion(attributes: String, bounds: LayerTree.Rect, subregion: LayerTree.Rect) throws {
        let filter = try makeFilterLayer(##"<feImage href="#r" \##(attributes)/>"##)
        let image = try #require(filter.image)
        #expect(image.layer.bounds == bounds)
        #expect(filter.primitives[0].subregion == subregion)
    }

    // objectBoundingBox places the subregion in fractions of the bounding box (20, 20, 160, 160)
    @Test
    func elementSubregionInObjectBoundingBox() throws {
        let filter = try makeFilterLayer(
            ##"<feImage href="#r" x="0.25" y="0.5"/>"##,
            primitiveUnits: "objectBoundingBox"
        )
        let image = try #require(filter.image)
        #expect(image.layer.transform == [.translate(tx: 60, ty: 100)])
    }

    // the element keeps its own transform and opacity (link-to-an-element-with-transform, -with-opacity)
    @Test
    func elementKeepsItsTransformAndOpacity() throws {
        let filter = try makeFilterLayer(##"<feImage href="#t"/>"##)
        let image = try #require(filter.image)
        let element = try #require(
            image.layer.contents.first.flatMap {
                if case .layer(let layer) = $0 { return layer } else { return nil }
            }
        )
        #expect(element.transform == [.translate(tx: 10, ty: 0)])
        #expect(element.opacity == 0.5)
    }

    // the element inherits from its own ancestors, not from the filtered element
    @Test
    func elementInheritsFromItsAncestors() throws {
        let filter = try makeFilterLayer(##"<feImage href="#inner"/>"##)
        let image = try #require(filter.image)
        let fills = image.layer.fills
        #expect(fills == [.color(.rgba(r: 0, g: 0, b: 1, a: 1, space: .srgb))])
    }

    // link-to-g, link-to-use
    @Test(arguments: ["#g", "#u"])
    func elementMayBeAGroupOrUse(href: String) throws {
        let filter = try makeFilterLayer(##"<feImage href="\##(href)"/>"##)
        let image = try #require(filter.image)
        #expect(image.layer.bounds == LayerTree.Rect(x: 4, y: 4, width: 60, height: 60))
    }

    // empty, link-to-an-invalid-element: missing, empty or non-graphics references, an invalid element (a rect
    // without a size) and an image that cannot be loaded draw nothing
    @Test(arguments: [
        "<feImage/>",
        ##"<feImage href=""/>"##,
        ##"<feImage href="#missing"/>"##,
        ##"<feImage href="#lg"/>"##,
        ##"<feImage href="#f"/>"##,
        ##"<feImage href="#empty"/>"##,
        ##"<feImage href="image.png"/>"##,
    ])
    func unresolvedReferenceIsTransparent(primitive: String) throws {
        let filter = try makeFilterLayer(primitive)
        #expect(filter.effects == [.flood(.none)])
    }

    // self-recursive, recursive-links: an element drawing itself, directly or through an ancestor or another
    // filter, draws nothing there (as Chrome and Safari)
    @Test(arguments: [
        ##"<rect id="self" width="10" height="10" filter="url(#f)"/>"##,
        ##"<g id="self" filter="url(#f)"><rect width="10" height="10"/></g>"##,
    ])
    func recursiveReferenceDrawsNothing(element: String) throws {
        let svg = try DOM.SVG.parse(
            xml: ##"""
                <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
                    <filter id="f"><feImage href="#self"/></filter>
                    \##(element)
                </svg>
                """##
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        // the copy drawn inside the filter has the reference dropped
        let outer = try #require(layer.filtered.first)
        let inner = try #require(outer.filterImages[0]?.filtered.first)
        #expect(inner.filterImages.isEmpty)
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(200, 200),
            options: .default
        )
        #expect(generator.makeFilterLayer(for: inner)?.effects == [.flood(.none)])
    }

    // embedded-png, with-subregion: an image is fitted into the subregion before the filter region clips it
    @Test(
        arguments: [
            ("", LayerTree.Rect(x: 4, y: 4, width: 192, height: 192)),
            (##"x="50" width="100""##, LayerTree.Rect(x: 50, y: 4, width: 100, height: 192)),
            (##"x="-20" width="100""##, LayerTree.Rect(x: -20, y: 4, width: 100, height: 192)),
        ] as [(String, LayerTree.Rect)]
    )
    func imageFillsTheSubregion(attributes: String, frame: LayerTree.Rect) throws {
        let filter = try makeFilterLayer(
            ##"<feImage href="\##(Self.png)" preserveAspectRatio="none" \##(attributes)/>"##
        )
        let image = try #require(filter.image)
        let bitmap = try #require(image.layer.images.first)
        #expect(
            LayerTree.Rect(x: bitmap.origin.x, y: bitmap.origin.y, width: bitmap.width ?? 0, height: bitmap.height ?? 0)
                == frame
        )
        #expect(bitmap.preserveAspectRatio == .init(align: .none, meetOrSlice: .meet))
        #expect(image.layer.transform.isEmpty)
    }

    // with-subregion-1: objectBoundingBox fractions of the bounding box; y and height take the filter region
    @Test
    func imageSubregionInObjectBoundingBox() throws {
        let filter = try makeFilterLayer(
            ##"<feImage x="0.25" width="0.5" href="\##(Self.png)" image-rendering="pixelated"/>"##,
            primitiveUnits: "objectBoundingBox"
        )
        let image = try #require(filter.image)
        let bitmap = try #require(image.layer.images.first)
        #expect(bitmap.origin == LayerTree.Point(60, 4))
        #expect(bitmap.width == 80)
        #expect(bitmap.height == 192)
        #expect(image.isPixelated)
    }

    // the renderer is handed what each feImage draws, after the filter layer is pushed
    @Test
    func commandsCarryTheContents() throws {
        let svg = try DOM.SVG.parse(
            xml: ##"""
                <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
                    <filter id="f"><feFlood/><feImage href="#r" result="i"/><feComposite in="i" in2="SourceGraphic"/></filter>
                    <rect id="r" x="36" y="36" width="120" height="120" fill="green" />
                    <rect x="20" y="20" width="160" height="160" fill="red" filter="url(#f)" />
                </svg>
                """##
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(200, 200),
            options: .default
        )
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        let index = try #require(
            commands.firstIndex {
                if case .pushFilterLayer = $0 { return true } else { return false }
            }
        )
        // the flood is outside the primary tree: the image is primitive 0
        guard case let .filterImage(primitive, contents) = commands[index + 1] else {
            Issue.record("expected filterImage, got \(commands[index + 1])")
            return
        }
        #expect(primitive == 0)
        #expect(
            contents.contains {
                if case .fill = $0 { return true } else { return false }
            }
        )
    }

    // the image is the primitive's result, clipped to its subregion; without one it is transparent
    @Test
    func evaluatesTheRasterizedImage() {
        let region = LayerTree.Rect(x: 0, y: 0, width: 4, height: 2)
        let layer = LayerTree.Layer()
        let filter = LayerTree.FilterLayer(
            region: region,
            primitives: [
                .init(
                    effect: .image(.init(layer: layer, isPixelated: false)),
                    inputs: [],
                    subregion: LayerTree.Rect(x: 1, y: 0, width: 2, height: 2),
                    colorInterpolation: .linearRGB
                )
            ]
        )
        let opaque = FilterBitmap(width: 4, height: 2, pixels: [UInt8](repeating: 255, count: 32))
        var requested = [Int]()
        let environment = LayerTree.FilterLayer.Environment(
            transform: .identity,
            blur: { _, _, _ in },
            image: {
                requested.append($0); return opaque
            }
        )
        let result = filter.evaluate(source: FilterBitmap(width: 4, height: 2), environment: environment)
        #expect(requested == [0])
        #expect(result.pixel(x: 0, y: 0) == [0, 0, 0, 0])
        #expect(result.pixel(x: 1, y: 1) == [255, 255, 255, 255])
        #expect(result.pixel(x: 2, y: 0) == [255, 255, 255, 255])
        #expect(result.pixel(x: 3, y: 1) == [0, 0, 0, 0])

        let missing = LayerTree.FilterLayer.Environment(transform: .identity, blur: { _, _, _ in })
        #expect(filter.evaluate(source: opaque, environment: missing) == FilterBitmap(width: 4, height: 2))
    }
}

private extension LayerTreeFilterImageTests {

    func makeFilterLayer(_ primitive: String, primitiveUnits: String = "userSpaceOnUse") throws -> LayerTree.FilterLayer
    {
        let svg = try DOM.SVG.parse(
            xml: ##"""
                <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
                    <defs>
                        <rect id="r" x="36" y="36" width="120" height="120" fill="green" />
                        <rect id="t" width="60" height="60" fill="green" opacity="0.5" transform="translate(10)" />
                        <rect id="empty" fill="green" />
                        <g id="g"><rect width="60" height="60" fill="green" /></g>
                        <use id="u" href="#g" />
                        <g id="blues" fill="blue"><rect id="inner" width="60" height="60" /></g>
                        <linearGradient id="lg"><stop offset="0" stop-color="green" /></linearGradient>
                    </defs>
                    <filter id="f" primitiveUnits="\##(primitiveUnits)">\##(primitive)</filter>
                    <rect x="20" y="20" width="160" height="160" fill="red" filter="url(#f)" />
                </svg>
                """##
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(200, 200),
            options: .default
        )
        let commands = generator.renderCommands(for: layer, colorConverter: .default)
        return try #require(
            commands.compactMap {
                if case .pushFilterLayer(let filter) = $0 { return filter }
                return nil
            }.first
        )
    }
}

private extension LayerTree.FilterLayer {
    var image: Image? {
        for case .image(let image) in effects { return image }
        return nil
    }
}

private extension LayerTree.Layer {

    // the layers with filters, in drawing order
    var filtered: [LayerTree.Layer] {
        (filters.isEmpty ? [] : [self])
            + contents.flatMap { contents -> [LayerTree.Layer] in
                if case .layer(let layer) = contents { return layer.filtered } else { return [] }
            }
    }

    // the bounds of the shapes and images, in this layer's space (its own transform applied)
    var bounds: LayerTree.Rect? {
        let generator = LayerTree.CommandGenerator(
            provider: LayerTreeProvider(),
            size: .init(200, 200),
            options: .default
        )
        let wrapper = LayerTree.Layer()
        wrapper.contents = [.layer(self)]
        return generator.makeBounds(for: wrapper)
    }

    var images: [LayerTree.Image] {
        contents.flatMap { contents -> [LayerTree.Image] in
            switch contents {
            case .image(let image): return [image]
            case .layer(let layer): return layer.images
            default: return []
            }
        }
    }

    var fills: [LayerTree.FillAttributes.Fill] {
        contents.flatMap { contents -> [LayerTree.FillAttributes.Fill] in
            switch contents {
            case .shape(_, _, let fill): return [fill.fill]
            case .layer(let layer): return layer.fills
            default: return []
            }
        }
    }
}
