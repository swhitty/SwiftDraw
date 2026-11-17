//
//  DOM.FontSizeTests.swift
//  SwiftDraw
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
import Foundation
import Testing

struct DOMFontSizeTests {

    @Test(arguments: [
        ("12", DOM.FontSize.length(12)),
        ("12px", .length(12)),
        ("12pt", .length(16)),
        ("0", .length(0)),
        ("3em", .relative(3)),
        ("200%", .relative(2)),
        ("5ex", .ex(5)),
        ("xx-small", .keyword(.xxSmall)),
        (" Medium ", .keyword(.medium)),
        ("xxx-large", .keyword(.xxxLarge)),
        ("larger", .larger),
        ("smaller", .smaller),
    ])
    func parses(_ text: String, _ expected: DOM.FontSize) {
        #expect(DOM.FontSize(text) == expected)
    }

    @Test(arguments: ["-5", "-10%", "big", "12qq", ""])
    func rejectsInvalidValues(_ text: String) {
        #expect(DOM.FontSize(text) == nil)
    }

    @Test(arguments: [
        (DOM.FontSize.length(10), Float(10)),
        (.relative(1.5), 30),
        (.ex(1), 10),
        (.keyword(.medium), 16),
        (.keyword(.xxLarge), 32),
        (.larger, 24),
        (.smaller, Float(50) / 3),
    ])
    func resolvesAgainstTheParent(_ size: DOM.FontSize, _ expected: Float) {
        #expect(abs(size.resolved(inheriting: 20) - expected) < 0.0001)
    }

    @Test
    func presentationAttributeKeepsTheSpecifiedValue() throws {
        let xml =
            #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><g font-size="3em"><text style="font-size: larger">A</text></g></svg>"#
        let svg = try DOM.SVG.parse(data: Data(xml.utf8))
        let group = try #require(svg.childElements.first as? DOM.Group)
        #expect(group.attributes.fontSize == .relative(3))
        #expect(group.childElements.first?.style.fontSize == .larger)
    }
}
