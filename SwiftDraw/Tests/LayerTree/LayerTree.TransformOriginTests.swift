//
//  LayerTree.TransformOriginTests.swift
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


@testable import SwiftDraw
import SwiftDrawDOM
import Foundation
import Testing

/// `transform-origin` (CSS Transforms 1 §6): a transform around an origin is
/// `translate(o) · transform · translate(-o)`, with percentages of the viewport.
struct LayerTreeTransformOriginTests {

    typealias Matrix = LayerTree.Transform.Matrix

    @Test(arguments: [
        ("center", "100 100"),
        ("50% 50%", "100 100"),
        ("100px 100px", "100 100"),
        ("left", "0 100"),
        ("right bottom", "200 200"),
        ("top", "100 0"),
        ("25% top", "50 0"),
        ("0 0", "0 0"),
    ])
    func shape(_ origin: String, _ point: String) throws {
        let layer = try makeElementLayer(#"<rect width="10" height="10" transform="rotate(45)" transform-origin="\#(origin)" />"#)
        let expected = try makeElementLayer(#"<rect width="10" height="10" transform="translate(\#(point)) rotate(45) translate(\#(negated(point)))" />"#)
        #expect(layer.transform.toMatrix().isClose(to: expected.transform.toMatrix()))
    }

    @Test(arguments: ["g", "use", "image"])
    func groupUseAndImage(_ name: String) throws {
        let element: String
        switch name {
        case "use": element = ##"<use href="#r" transform="scale(2)" transform-origin="center" />"##
        case "image": element = #"<image width="10" height="10" href="data:image/png;base64,iVBORw0KGgo=" transform="scale(2)" transform-origin="center" />"#
        default: element = #"<g transform="scale(2)" transform-origin="center"><rect width="10" height="10" /></g>"#
        }
        let svg = try parse(#"<defs><rect id="r" width="10" height="10" /></defs>"# + element)
        let layer = try #require(makeLayers(svg).first { !$0.transform.isEmpty })
        #expect(layer.transform.toMatrix().isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: -100, ty: -100)))
    }

    @Test
    func viewportIsTheViewBox() throws {
        let layer = try makeElementLayer(#"<rect width="10" height="10" transform="scale(2)" transform-origin="50% 25%" />"#,
                                         size: #"width="400" height="200" viewBox="0 0 100 40""#)
        #expect(layer.transform.toMatrix().isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: -50, ty: -10)))
    }

    @Test
    func withoutTransformItHasNoEffect() throws {
        let svg = try parse(#"<rect width="10" height="10" transform-origin="center" />"#)
        let transforms = makeLayers(svg).map(\.transform)
        #expect(transforms.allSatisfy { $0.isEmpty })
    }

    @Test
    func isNotInherited() throws {
        let svg = try parse(#"<g transform-origin="center"><rect width="10" height="10" transform="scale(2)" /></g>"#)
        let layer = try #require(makeLayers(svg).first { !$0.transform.isEmpty })
        #expect(layer.transform.toMatrix().isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0)))
    }

    @Test(arguments: ["userSpaceOnUse", "objectBoundingBox"])
    func clipPath(_ units: String) throws {
        // the clipPath transform applies in user space after the bounding box mapping, so is its origin
        let svg = try parse("""
        <clipPath id="c" clipPathUnits="\(units)" transform="scale(2)" transform-origin="center">
          <rect width="1" height="1" />
        </clipPath>
        <rect width="200" height="200" clip-path="url(#c)" />
        """)
        let clip = try #require(makeLayers(svg).flatMap(\.clip).first)
        let units = units == "objectBoundingBox" ? Matrix(a: 200, b: 0, c: 0, d: 200, tx: 0, ty: 0) : .identity
        let expected = units.concatenated(Matrix(a: 2, b: 0, c: 0, d: 2, tx: -100, ty: -100))
        #expect(clip.transform.isClose(to: expected))
    }

    @Test
    func clipPathMember() throws {
        let svg = try parse("""
        <clipPath id="c"><rect width="10" height="10" transform="scale(2)" transform-origin="right bottom" /></clipPath>
        <rect width="200" height="200" clip-path="url(#c)" />
        """)
        let clip = try #require(makeLayers(svg).flatMap(\.clip).first)
        #expect(clip.transform.isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: -200, ty: -200)))
    }

    @Test(arguments: ["linearGradient", "radialGradient"])
    func gradient(_ name: String) throws {
        let svg = try parse("""
        <\(name) id="g" gradientTransform="scale(2)" transform-origin="0.5 0.5">
          <stop offset="0" stop-color="black" /><stop offset="1" stop-color="white" />
        </\(name)>
        <rect width="10" height="10" fill="url(#g)" />
        """)
        let transform: [LayerTree.Transform]
        switch try #require(makeFills(svg).first) {
        case .linearGradient(let g): transform = g.transform
        case .radialGradient(let g): transform = g.transform
        default: Issue.record("expected a gradient"); return
        }
        #expect(transform.toMatrix().isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: -0.5, ty: -0.5)))
    }

    @Test
    func gradientPercentagesResolveAgainstTheViewport() throws {
        let svg = try parse("""
        <radialGradient id="g" gradientUnits="userSpaceOnUse" gradientTransform="scale(2)" transform-origin="center">
          <stop offset="0" stop-color="black" /><stop offset="1" stop-color="white" />
        </radialGradient>
        <rect width="10" height="10" fill="url(#g)" />
        """)
        guard case .radialGradient(let g) = try #require(makeFills(svg).first) else {
            Issue.record("expected a radial gradient"); return
        }
        #expect(g.transform.toMatrix().isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: -100, ty: -100)))
    }

    @Test
    func pattern() throws {
        let svg = try parse("""
        <pattern id="p" patternUnits="userSpaceOnUse" width="200" height="200" patternTransform="scale(2)" transform-origin="center">
          <rect width="50" height="50" />
        </pattern>
        <rect width="10" height="10" fill="url(#p)" />
        """)
        guard case .pattern(let p) = try #require(makeFills(svg).first) else {
            Issue.record("expected a pattern"); return
        }
        #expect(p.transform.isClose(to: Matrix(a: 2, b: 0, c: 0, d: 2, tx: -100, ty: -100)))
    }

    @Test
    func rootDefaultsToTheCenterOfTheViewport() throws {
        let svg = try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 100 100" transform="scale(0.5)"><rect width="10" height="10" /></svg>"#)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        // scale(0.5) around (100, 100) in the viewport, then the viewBox mapping scale(2)
        #expect(root.transform.toMatrix().isClose(to: Matrix(a: 1, b: 0, c: 0, d: 1, tx: 50, ty: 50)))
    }

    @Test
    func rootOriginResolvesAgainstItsViewport() throws {
        let svg = try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 100 100" transform="scale(0.5)" transform-origin="25% 75%"><rect width="10" height="10" /></svg>"#)
        let root = LayerTree.Builder(svg: svg).makeLayer()
        #expect(root.transform.toMatrix().isClose(to: Matrix(a: 1, b: 0, c: 0, d: 1, tx: 25, ty: 75)))
    }

    // MARK: - Helpers

    private func negated(_ point: String) -> String {
        point.split(separator: " ").map { $0 == "0" ? "0" : "-\($0)" }.joined(separator: " ")
    }

    private func parse(_ body: String, size: String = #"width="200" height="200""#) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" \#(size)>\#(body)</svg>"#)
    }

    /// The layer of the only element in the document
    private func makeElementLayer(_ body: String, size: String = #"width="200" height="200""#) throws -> LayerTree.Layer {
        let root = LayerTree.Builder(svg: try parse(body, size: size)).makeLayer()
        let layers = root.contents.compactMap { if case .layer(let l) = $0 { return l } else { return nil } }
        return try #require(layers.first)
    }

    private func makeLayers(_ svg: DOM.SVG) -> [LayerTree.Layer] {
        var result = [LayerTree.Layer]()
        var stack = [LayerTree.Builder(svg: svg).makeLayer()]
        while let layer = stack.popLast() {
            result.append(layer)
            for case .layer(let child) in layer.contents {
                stack.append(child)
            }
        }
        return result
    }

    private func makeFills(_ svg: DOM.SVG) -> [LayerTree.FillAttributes.Fill] {
        makeLayers(svg).flatMap(\.contents).compactMap {
            if case .shape(_, _, let fill) = $0 { return fill.fill } else { return nil }
        }
    }
}

private extension LayerTree.Transform.Matrix {
    func isClose(to other: Self, tolerance: LayerTree.Float = 1e-3) -> Bool {
        [a - other.a, b - other.b, c - other.c, d - other.d, tx - other.tx, ty - other.ty]
            .allSatisfy { abs($0) <= tolerance }
    }
}
