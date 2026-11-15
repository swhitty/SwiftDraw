//
//  CGTextFilterTests.swift
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
import Foundation
import Testing

/// Filters through the CGText code generator, which cannot render them.
struct CGTextFilterTests {

    @Test
    func filterLayerIsolatesGraphicsState() throws {
        let xml = #"""
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <filter id="blur"><feGaussianBlur stdDeviation="2" /></filter>
            <rect x="10" y="10" width="20" height="20" fill="red" filter="url(#blur)" />
            <rect x="50" y="50" width="20" height="20" fill="black" />
        </svg>
        """#
        let code = try CGTextRenderer.render(data: Data(xml.utf8), options: .default, api: .uiKit, precision: 2)
        let lines = code.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        let warning = try #require(lines.firstIndex { $0.hasPrefix("// warning: filter dropped") })
        let save = try #require(lines.firstIndex(of: "ctx.saveGState()"))
        let restore = try #require(lines.lastIndex(of: "ctx.restoreGState()"))
        let lastFill = try #require(lines.lastIndex { $0.hasPrefix("ctx.setFillColor") })
        #expect(warning < save)
        #expect(save < restore)
        #expect(lastFill > restore)
    }
}
