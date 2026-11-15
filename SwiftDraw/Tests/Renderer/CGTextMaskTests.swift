//
//  CGTextMaskTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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
import Foundation
import Testing

/// Masks through the CGText code generator, which draws them into a greyscale bitmap as CGRenderer does.
struct CGTextMaskTests {

    @Test
    func maskIsDrawnIntoGreyscaleBitmapThenClipped() throws {
        let lines = try makeLines(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <mask id="m">
                <rect width="100" height="100" fill="white" />
                <rect width="50" height="100" fill="black" opacity="0.5" />
            </mask>
            <rect width="100" height="100" fill="red" mask="url(#m)" />
        </svg>
        """#)

        let create = try #require(lines.firstIndex { $0.hasPrefix("let maskContext1 = CGContext(") })
        let scope = try #require(lines.firstIndex(of: "let ctx = maskContext1"))
        let clip = try #require(lines.firstIndex(of: "ctx.clip(to: maskRect1, mask: maskContext1.makeImage()!)"))
        let layer = try #require(lines.lastIndex(of: "ctx.beginTransparencyLayer(auxiliaryInfo: nil)"))
        #expect(lines.contains("space: CGColorSpaceCreateDeviceGray(),"))
        #expect(create < scope)
        #expect(scope < clip)
        #expect(clip < layer)
        #expect(!lines.contains { $0.hasPrefix("ctx.setBlendMode") })
    }

    @Test
    func identifiersDeclaredInMaskAreDeclaredAgainOutside() throws {
        // the same colour is used inside the mask's scope and after it
        let lines = try makeLines(#"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <mask id="m"><rect width="100" height="100" fill="white" /></mask>
            <rect width="100" height="100" fill="white" mask="url(#m)" />
        </svg>
        """#)

        let declarations = lines.filter { $0.hasPrefix("let color1 = ") }
        #expect(declarations.count == 2)
        let close = try #require(lines.firstIndex(of: "}"))
        let outer = try #require(lines.lastIndex { $0.hasPrefix("let color1 = ") })
        #expect(outer > close)
    }

    func makeLines(_ xml: String) throws -> [String] {
        let code = try CGTextRenderer.render(data: Data(xml.utf8), options: .default, api: .uiKit, precision: 2)
        return code.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
