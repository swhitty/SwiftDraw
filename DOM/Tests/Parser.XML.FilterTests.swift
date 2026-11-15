//
//  Parser.XML.FilterTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 16/8/22.
//  Copyright 2022 Simon Whitty
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

@testable import SwiftDrawDOM
import Testing

struct ParserXMLFilterTests {

    @Test
    func parseFilters() throws {
        let child = XML.Element(name: "child")
        child.children = [XML.Element.makeMockFilter(), XML.Element.makeMockFilter()]

        let parent = XML.Element(name: "parent")
        parent.children = [XML.Element.makeMockFilter(), child]

        #expect(try XMLParser().parseFilters(child).count == 2)
        #expect(try XMLParser().parseFilters(parent).count == 3)
    }

    @Test
    func parseEffect() throws {
        let element = XML.Element.makeMockFilter(id: "blur")

        element.children = [
            .makeElement("feGaussianBlur", ["stdDeviation": "0.5"]),
            .makeElement("other")
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.id == "blur")
        #expect(filter.effects == [.gaussianBlur(stdDeviation: 0.5)])
    }

    @Test
    func parseBlurTwoValues() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [.makeElement("feGaussianBlur", ["stdDeviation": "3 1.5"])]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.gaussianBlur(stdDeviation: 3, stdDeviationY: 1.5)])
    }

    @Test
    func parseBlurMissingOrInvalidDeviationIsZero() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feGaussianBlur"),
            .makeElement("feGaussianBlur", ["stdDeviation": "abc"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.gaussianBlur(stdDeviation: 0), .gaussianBlur(stdDeviation: 0)])
    }

    @Test
    func parseRegionAndUnits() throws {
        let element = XML.Element(name: "filter", attributes: [
            "id": "f",
            "x": "-0.2", "y": "-20%", "width": "140%", "height": "1.4",
            "filterUnits": "objectBoundingBox",
            "primitiveUnits": "objectBoundingBox"
        ])

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.x == -0.2)
        #expect(filter.y == -0.2)
        #expect(filter.width == 1.4)
        #expect(filter.height == 1.4)
        #expect(filter.filterUnits == .objectBoundingBox)
        #expect(filter.primitiveUnits == .objectBoundingBox)
    }

    @Test
    func parseInvalidRegionKeepsDefaults() throws {
        let element = XML.Element(name: "filter", attributes: [
            "id": "f", "x": "left", "filterUnits": "bogus"
        ])

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.x == nil)
        #expect(filter.filterUnits == nil)
    }

    @Test
    func parseUnknownPrimitiveIsUnsupported() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feOffset", ["dx": "2"]),
            .makeElement("desc")
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [.unsupported(name: "feOffset")])
    }

    @Test
    func parseInputChain() throws {
        let element = XML.Element.makeMockFilter()
        element.children = [
            .makeElement("feGaussianBlur", ["in": "SourceGraphic", "stdDeviation": "1", "result": "a"]),
            .makeElement("feGaussianBlur", ["in": "a", "stdDeviation": "2"]),
            .makeElement("feGaussianBlur", ["in": "SourceAlpha", "stdDeviation": "3"])
        ]

        let filter = try XMLParser().parseFilter(element)
        #expect(filter.effects == [
            .gaussianBlur(stdDeviation: 1),
            .gaussianBlur(stdDeviation: 2),
            .unsupported(name: "feGaussianBlur")
        ])
    }
}

private extension XML.Element {

    static func makeMockFilter(id: String = "mock") -> XML.Element {
        return XML.Element(name: "filter", attributes: ["id": id])
    }

    static func makeElement(_ name: String, _ attributes: [String: String] = [:]) -> XML.Element {
        return XML.Element(name: name, attributes: attributes)
    }
}

/// Figma's layer blur: a transparent flood with the source blended over it in normal mode is a no-op.
struct ParserXMLFilterNoOpPreludeTests {

    private func effects(flood: [String: String], blend: [String: String], blur: Bool = true) throws -> [DOM.Filter.Effect] {
        let filter = XML.Element(name: "filter", attributes: ["id": "f"])
        filter.children = [.makeElement("feFlood", flood), .makeElement("feBlend", blend)]
        if blur {
            filter.children.append(.makeElement("feGaussianBlur", ["stdDeviation": "0.75"]))
        }
        return try XMLParser().parseFilter(filter).effects
    }

    private static let flood = ["flood-opacity": "0", "result": "BackgroundImageFix"]
    private static let blend = ["mode": "normal", "in": "SourceGraphic", "in2": "BackgroundImageFix", "result": "shape"]

    @Test
    func figmaLayerBlurIsAPlainBlur() throws {
        #expect(try effects(flood: Self.flood, blend: Self.blend) == [.gaussianBlur(stdDeviation: 0.75)])
    }

    @Test
    func blendModeDefaultsToNormal() throws {
        var blend = Self.blend
        blend["mode"] = nil
        #expect(try effects(flood: Self.flood, blend: blend) == [.gaussianBlur(stdDeviation: 0.75)])
    }

    @Test
    func preludeAloneLeavesNoEffects() throws {
        #expect(try effects(flood: Self.flood, blend: Self.blend, blur: false).isEmpty)
    }

    @Test
    func blurMayNameTheBlendResult() throws {
        let filter = XML.Element(name: "filter", attributes: ["id": "f"])
        filter.children = [
            .makeElement("feFlood", Self.flood),
            .makeElement("feBlend", Self.blend),
            .makeElement("feGaussianBlur", ["in": "shape", "stdDeviation": "2"])
        ]
        #expect(try XMLParser().parseFilter(filter).effects == [.gaussianBlur(stdDeviation: 2)])
    }

    // anything but the exact no-op pair stays unsupported
    @Test(arguments: [
        ("opaque flood", ["flood-opacity": "0.5", "result": "BackgroundImageFix"], blend),
        ("flood without opacity", ["result": "BackgroundImageFix"], blend),
        ("multiply blend", flood, ["mode": "multiply", "in": "SourceGraphic", "in2": "BackgroundImageFix"]),
        ("other input", flood, ["mode": "normal", "in": "SourceAlpha", "in2": "BackgroundImageFix"]),
        ("in2 not the flood", flood, ["mode": "normal", "in": "SourceGraphic", "in2": "Other"]),
        ("blend subregion", flood, ["mode": "normal", "in": "SourceGraphic", "in2": "BackgroundImageFix", "width": "5"])
    ])
    func otherFloodOrBlendStaysUnsupported(name: String, flood: [String: String], blend: [String: String]) throws {
        let effects = try effects(flood: flood, blend: blend)
        #expect(effects.contains(.unsupported(name: "feFlood")) || effects.contains(.unsupported(name: "feBlend")))
    }
}
