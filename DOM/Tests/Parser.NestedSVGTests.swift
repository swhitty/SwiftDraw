//
//  Parser.NestedSVGTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
//  Copyright 2026 WhileLoop Pty Ltd. All rights reserved.
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
import Testing

struct ParserNestedSVGTests {

    @Test
    func nestedSVGChildrenAreParsedOnce() throws {
        let svg = try DOM.SVG.parse(
            xml: """
                <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <svg width="50" height="50">
                    <rect width="10" height="10"/>
                    <g><circle r="5"/></g>
                  </svg>
                </svg>
                """
        )
        let nested = try #require(svg.childElements.first as? DOM.SVG)
        #expect(svg.childElements.count == 1)
        #expect(nested.childElements.count == 2)
        #expect(nested.childElements.first is DOM.Rect)
        let group = try #require(nested.childElements.last as? DOM.Group)
        #expect(group.childElements.count == 1)
    }
}
