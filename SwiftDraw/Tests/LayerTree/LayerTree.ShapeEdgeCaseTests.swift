//
//  LayerTree.ShapeEdgeCaseTests.swift
//  SwiftDraw
//
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
@testable import SwiftDraw
import Testing

/// Invalid and edge-case shape attributes and path data (SVG 2 §9, §10), as in resvg's `shapes` tests.
struct LayerTreeShapeEdgeCaseTests {

    private func shapes(_ body: String) throws -> [LayerTree.Shape] {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">\(body)</svg>
                """
        )
        return shapes(in: LayerTree.Builder(svg: svg).makeLayer())
    }

    private func shapes(in layer: LayerTree.Layer) -> [LayerTree.Shape] {
        layer.contents.flatMap { contents -> [LayerTree.Shape] in
            switch contents {
            case .layer(let child): shapes(in: child)
            case let .shape(shape, _, _): [shape]
            default: []
            }
        }
    }

    private func path(_ d: String) throws -> LayerTree.Shape {
        try #require(shapes(#"<path d="\#(d)"/>"#).first)
    }

    @Test(arguments: [
        #"<circle cx="100" cy="100" r="-80"/>"#,
        #"<circle cx="100" cy="100" r="0"/>"#,
        #"<ellipse cx="90" cy="100" rx="-80" ry="-60"/>"#,
        #"<ellipse cx="90" cy="100"/>"#,
        #"<ellipse cx="90" cy="100" rx="0" ry="60"/>"#,
        #"<rect x="20" y="20" width="-10" height="160"/>"#,
        #"<rect x="20" y="20" width="160" height="-10"/>"#,
        #"<rect x="20" y="20" width="0" height="160"/>"#,
    ])
    func invalidOrEmptyShapeRendersNothing(element: String) throws {
        #expect(try shapes(element).isEmpty)
    }

    @Test(arguments: [
        #"<ellipse cx="100" cy="100" ry="60"/>"#,
        #"<ellipse cx="100" cy="100" rx="60"/>"#,
        #"<ellipse cx="100" cy="100" rx="-5" ry="60"/>"#,
        #"<ellipse cx="100" cy="100" rx="auto" ry="60"/>"#,
    ])
    func autoEllipseRadiusUsesTheOther(element: String) throws {
        #expect(try shapes(element) == [.ellipse(within: LayerTree.Rect(x: 40, y: 40, width: 120, height: 120))])
    }

    @Test(arguments: [
        (#"rx="-20" ry="20""#, LayerTree.Size(20, 20)),
        (#"rx="20" ry="-20""#, LayerTree.Size(20, 20)),
        (#"rx="15""#, LayerTree.Size(15, 15)),
        (#"rx="200""#, LayerTree.Size(80, 40)),
        (#"rx="100" ry="10""#, LayerTree.Size(80, 10)),
    ])
    func rectRadii(attributes: String, radii: LayerTree.Size) throws {
        let rect = LayerTree.Rect(x: 20, y: 20, width: 160, height: 80)
        #expect(
            try shapes(#"<rect x="20" y="20" width="160" height="80" \#(attributes)/>"#) == [
                .rect(within: rect, radii: radii)
            ]
        )
    }

    @Test(arguments: [
        "M 30 40 L 110 160 L 150#80",
        "M 30 40 L 110 160 L 150",
        "M 30 40 L 110 160 X 10 10",
        "M 30 40 110 160 150",
    ])
    func pathRendersUpToTheFirstError(d: String) throws {
        #expect(try path(d) == path("M 30 40 L 110 160"))
    }

    @Test(arguments: [
        // S/T after a command that is not C/S or Q/T: the first control point is the current point
        ("M 30 40 A 40 30 20 1 1 150 100 s 20 30 -80 50", "M 30 40 A 40 30 20 1 1 150 100 c 0 0 20 30 -80 50"),
        ("M 30 40 A 40 30 20 1 1 150 100 t -80 50", "M 30 40 A 40 30 20 1 1 150 100 q 0 0 -80 50"),
        ("M 30 30 T 40 170 S 170 170 170 30", "M 30 30 Q 30 30 40 170 C 40 170 170 170 170 30"),
        ("M 30 30 T 40 170 s 90 -20 90 -90", "M 30 30 Q 30 30 40 170 C 40 170 130 150 130 80"),
        ("M 0 0 Q 50 -50 100 0 S 150 50 200 0", "M 0 0 Q 50 -50 100 0 C 100 0 150 50 200 0"),
        ("M 0 0 C 10 10 40 10 50 0 T 100 0", "M 0 0 C 10 10 40 10 50 0 Q 50 0 100 0"),
        // S after C/S and T after Q/T reflect the previous control point
        ("M 0 0 C 10 10 40 10 50 0 S 90 -10 100 0", "M 0 0 C 10 10 40 10 50 0 C 60 -10 90 -10 100 0"),
        ("M 0 0 Q 50 -50 100 0 T 200 0", "M 0 0 Q 50 -50 100 0 Q 150 50 200 0"),
        ("M 0 0 Q 50 -50 100 0 T 200 0 T 300 0", "M 0 0 Q 50 -50 100 0 Q 150 50 200 0 Q 250 -50 300 0"),
    ])
    func smoothCurveControlPoints(d: String, expected: String) throws {
        #expect(try path(d) == path(expected))
    }

    @Test(arguments: [
        ("M 10 10 L 10 20 L 20 10 z L 100 100 L 120 100", "M 10 10 L 10 20 L 20 10 z M 10 10 L 100 100 L 120 100"),
        ("M 10 10 L 10 20 L 20 10 z l 90 90", "M 10 10 L 10 20 L 20 10 z M 10 10 L 100 100"),
        ("M 10 10 L 10 20 z m 5 5 l 10 0", "M 10 10 L 10 20 z M 15 15 L 25 15"),
    ])
    func closePathReturnsToTheSubpathStart(d: String, expected: String) throws {
        #expect(try path(d) == path(expected))
    }

    @Test(arguments: [
        #"<polyline points="20 40 160 180 30 150 300"/>"#,
        #"<polygon points="20 40 160 180 30 150 300"/>"#,
        #"<polygon points="20 40 160 180 30,150 # 1 2"/>"#,
    ])
    func pointsIgnoreAnOddCoordinateAndAnythingAfterAnError(element: String) throws {
        let points = [LayerTree.Point(20, 40), LayerTree.Point(160, 180), LayerTree.Point(30, 150)]
        let expected: LayerTree.Shape =
            element.hasPrefix("<polyline") ? .line(between: points) : .polygon(between: points)
        #expect(try shapes(element) == [expected])
    }
}
