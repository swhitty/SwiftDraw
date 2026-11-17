//
//  CGPath+SegmentTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 20/11/18.
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

#if canImport(CoreGraphics)
import CoreGraphics
import CoreText
import Testing
@testable import SwiftDraw

struct CGPathSegmentTests {

    @Test
    func segmentsAreReadFromPath() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 100))
        path.addQuadCurve(
            to: CGPoint(x: 100, y: 100),
            control: CGPoint(x: 50, y: 50)
        )
        path.addCurve(
            to: CGPoint(x: 200, y: 100),
            control1: CGPoint(x: 100, y: 50),
            control2: CGPoint(x: 200, y: 150)
        )
        path.closeSubpath()

        #expect(
            path.segments() == [
                .move(CGPoint(x: 0, y: 0)),
                .line(CGPoint(x: 0, y: 100)),
                .quad(CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 100)),
                .cubic(CGPoint(x: 100, y: 50), CGPoint(x: 200, y: 150), CGPoint(x: 200, y: 100)),
                .close,
            ]
        )
    }

    @Test
    func glyphPathSegments() throws {
        let font = CTFontCreateWithName("Helvetica" as CFString, 10.0, nil)
        let path = try #require("_".toPath(font: font))

        let segments = path.segments()
        try #require(segments.count == 5)
        guard case .move = segments[0] else {
            Issue.record("expected move")
            return
        }
        for segment in segments[1...3] {
            guard case .line = segment else {
                Issue.record("expected line")
                return
            }
        }
        #expect(segments[4] == .close)
    }
}

#endif
