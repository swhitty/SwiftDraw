//
//  LayerTree.ConditionalProcessingTests.swift
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
import Testing

/// SVG 2 §5.8 conditional processing: `<switch>` renders its first direct child whose
/// `systemLanguage` and `requiredExtensions` evaluate to true, and other elements whose
/// conditions fail are not rendered. Each rect is identified by its width.
struct LayerTreeConditionalProcessingTests {

    @Test(
        arguments: [
            // no conditions: the first child
            (#"<rect width="1" height="1"/><rect width="2" height="1"/>"#, [1]),
            // requiredExtensions fails whatever its value
            (
                #"<rect width="1" height="1" requiredExtensions="http://example.org/bogus"/><rect width="2" height="1"/>"#,
                [2]
            ),
            (#"<rect width="1" height="1" requiredExtensions=""/><rect width="2" height="1"/>"#, [2]),
            // requiredFeatures was removed in SVG 2 and is ignored, as in browsers
            (
                #"<rect width="1" height="1" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Shape"/><rect width="2" height="1"/>"#,
                [1]
            ),
            (#"<rect width="1" height="1" systemLanguage="ru-RU"/><rect width="2" height="1"/>"#, [2]),
            (#"<rect width="1" height="1" systemLanguage="en"/><rect width="2" height="1"/>"#, [1]),
            // a selected child that draws nothing still ends the switch
            (#"<rect width="1" height="1" display="none"/><rect width="2" height="1"/>"#, []),
            // no child passes
            (
                #"<rect width="1" height="1" systemLanguage="ru"/><rect width="2" height="1" requiredExtensions="x"/>"#,
                []
            ),
            // only direct children are considered, a group's conditions included
            (
                #"<g systemLanguage="fr"><rect width="1" height="1"/></g><g><rect width="2" height="1"/><rect width="3" height="1"/></g>"#,
                [2, 3]
            ),
        ] as [(String, [Float])]
    )
    func switchSelectsFirstPassingChild(_ children: String, _ widths: [Float]) throws {
        let svg = try parse("<switch>\(children)</switch>")
        #expect(rectWidths(svg, languages: ["en-US"]) == widths)
    }

    @Test(arguments: [
        ("en", true),
        ("en-US", true),
        ("en-GB", true),
        ("EN-gb", true),
        ("ru, en", true),
        ("ru,en-AU", true),
        ("ru-RU", false),
        ("is", false),
        ("", false),
        (" , ", false),
    ])
    func systemLanguageMatchesPrimarySubtag(_ value: String, _ matches: Bool) throws {
        let svg = try parse(
            #"<switch><rect width="1" height="1" systemLanguage="\#(value)"/><rect width="2" height="1"/></switch>"#
        )
        #expect(rectWidths(svg, languages: ["en-US"]) == (matches ? [1] : [2]))
    }

    @Test
    func systemLanguageUsesEveryPreferredLanguage() throws {
        let svg = try parse(
            #"<switch><rect width="1" height="1" systemLanguage="ru"/><rect width="2" height="1"/></switch>"#
        )
        #expect(rectWidths(svg, languages: ["de_DE", "ru-RU"]) == [1])
        #expect(rectWidths(svg, languages: ["de_DE"]) == [2])
        #expect(rectWidths(svg, languages: []) == [2])
    }

    @Test
    func switchKeepsItsOwnAttributes() throws {
        let svg = try parse(
            #"<switch fill="green" transform="scale(2)"><rect width="1" height="1" requiredExtensions="x"/><rect width="2" height="1"/></switch>"#
        )
        let root = LayerTree.Builder(svg: svg, languages: ["en"]).makeLayer()
        let layer = try #require(
            root.contents.compactMap { if case .layer(let l) = $0 { return l } else { return nil } }.first
        )
        #expect(layer.transform == [.scale(sx: 2, sy: 2)])
        #expect(rectWidths(svg, languages: ["en"]) == [2])
    }

    @Test
    func failingConditionsOutsideSwitchRemoveTheElement() throws {
        let svg = try parse(
            #"""
            <rect width="1" height="1"/>
            <rect width="2" height="1" systemLanguage="ru-RU"/>
            <g requiredExtensions="x"><rect width="3" height="1"/></g>
            <rect width="4" height="1" systemLanguage="en"/>
            """#
        )
        #expect(rectWidths(svg, languages: ["en-US"]) == [1, 4])
    }

    @Test
    func useOfFailingElementDrawsNothing() throws {
        let svg = try parse(
            ##"<defs><rect id="r" width="1" height="1" systemLanguage="ru"/></defs><use href="#r"/><use href="#r" systemLanguage="ru"/>"##
        )
        #expect(rectWidths(svg, languages: ["en"]).isEmpty)
        #expect(rectWidths(svg, languages: ["ru"]) == [1, 1])
    }

    @Test
    func rootSVGWithFailingConditionsDrawsNothing() throws {
        let svg = try DOM.SVG.parse(
            xml:
                #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" systemLanguage="ru-RU"><rect width="1" height="1"/></svg>"#
        )
        #expect(svg.systemLanguage == "ru-RU")
        #expect(rectWidths(svg, languages: ["en-US"]).isEmpty)
        #expect(rectWidths(svg, languages: ["ru"]) == [1])
    }

    @Test
    func domParsesConditionalAttributes() throws {
        let svg = try parse(
            #"<switch><rect width="1" height="1" systemLanguage="en, fr" requiredExtensions=""/></switch>"#
        )
        let sw = try #require(svg.childElements.first as? DOM.Switch)
        let rect = try #require(sw.childElements.first)
        #expect(rect.systemLanguage == "en, fr")
        #expect(rect.requiredExtensions == "")
        #expect(sw.systemLanguage == nil)
        #expect(sw.requiredExtensions == nil)
    }

    private func parse(_ body: String) throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\#(body)</svg>"#)
    }

    /// The widths of the rects drawn, in document order.
    private func rectWidths(_ svg: DOM.SVG, languages: [String]) -> [Float] {
        var result = [Float]()
        var stack = [LayerTree.Builder(svg: svg, languages: languages).makeLayer()]
        while let layer = stack.popLast() {
            for content in layer.contents {
                if case .shape(.rect(let rect, _), _, _) = content {
                    result.append(Float(rect.size.width))
                }
            }
            for case .layer(let child) in layer.contents.reversed() {
                stack.append(child)
            }
        }
        return result
    }
}
