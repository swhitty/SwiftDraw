//
//  LayerTree.FontSizeTests.swift
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

@testable import SwiftDraw
import SwiftDrawDOM
import Foundation
import Testing

/// `font-size` keeps its specified value in the DOM and resolves against the parent while cascading (CSS Fonts 4 §2.5).
struct LayerTreeFontSizeTests {

    @Test(arguments: [
        // nested em
        (#"<g font-size="12"><g font-size="3em"><g><g font-size="1em"><text>A</text></g></g></g></g>"#, Float(36)),
        // percentages, nested
        (#"<g font-size="20"><text font-size="200%">A</text></g>"#, 40),
        (#"<g font-size="40"><g font-size="200%"><g><text font-size="50%">A</text></g></g></g>"#, 40),
        // ex is half an em
        (#"<g font-size="36"><g font-size="3ex"><g font-size="1ex"><text>A</text></g></g></g>"#, 27),
        // absolute units
        (#"<g font-size="12pt"><text>A</text></g>"#, 16),
        // larger / smaller scale the parent by 1.2
        (#"<g font-size="40"><g font-size="larger"><text>A</text></g></g>"#, 48),
        (#"<g font-size="48"><g font-size="smaller"><text>A</text></g></g>"#, 40),
        (#"<g font-size="40"><g font-size="larger"><text font-size="80%">A</text></g></g>"#, 38.4),
        // keywords are absolute, with medium = 16
        (#"<g font-size="100"><g font-size="medium"><text>A</text></g></g>"#, 16),
        (#"<g font-size="5" style="font-size: xx-large"><text>A</text></g>"#, 32),
        (#"<g font-size="12"><g font-size="x-small"><text>A</text></g></g>"#, 10),
        // style="" and stylesheets
        (#"<style>.big { font-size: 2em }</style><g font-size="10"><g class="big"><text>A</text></g></g>"#, 20),
        (#"<g font-size="10"><g style="font-size: 150%"><text>A</text></g></g>"#, 15),
        // a negative size is invalid and ignored
        (#"<g font-size="30"><g font-size="-5"><text>A</text></g></g>"#, 30),
    ])
    func nestedSizesResolveAgainstTheParent(_ body: String, _ expected: Float) throws {
        #expect(try abs(fontSize(of: body) - expected) < 0.001)
    }

    @Test(arguments: [
        ("", Float(16)),
        (#"font-size="3em""#, 48),
        (#"font-size="300%""#, 48),
        (#"font-size="5ex""#, 40),
        (#"font-size="larger""#, 19.2),
        (#"style="font-size: 2em""#, 32),
    ])
    func rootResolvesAgainstTheInitialSize(_ root: String, _ expected: Float) throws {
        #expect(try abs(fontSize(of: "<text>A</text>", root: root) - expected) < 0.001)
    }

    @Test
    func zeroSizeDrawsNothing() throws {
        for body in [#"<text font-size="0">A</text>"#, #"<g font-size="0"><text font-size="50%">A</text></g>"#] {
            let layer = try makeLayer(body)
            #expect(layer.allContents.isEmpty, "\(body)")
        }
        // a size on the text itself replaces a zero size on its parent
        #expect(try fontSize(of: #"<g font-size="0"><text font-size="40">A</text></g>"#) == 40)
    }

    @Test
    func emLengthsUseTheComputedFontSize() throws {
        let svg = try parse(#"""
            <g font-size="10">
                <g font-size="2em"><rect width="10em" height="1ex"/><text x="1em" y="2em">A</text></g>
                <rect font-size="smaller" width="12em" height="1em"/>
                <rect font-size="large" width="1em" height="1em"/>
            </g>
            """#)
        let group = try #require(svg.childElements.first as? DOM.Group)
        let nested = try #require(group.childElements.first as? DOM.Group)
        let rect = try #require(nested.childElements.first as? DOM.Rect)
        #expect(rect.width == 200)
        #expect(rect.height == 10)
        let text = try #require(nested.childElements.last as? DOM.Text)
        #expect(text.x == 20)
        #expect(text.y == 40)
        let smaller = try #require(group.childElements[1] as? DOM.Rect)
        #expect(abs(smaller.width - 100) < 0.001)
        let large = try #require(group.childElements[2] as? DOM.Rect)
        #expect(large.width == 18)
    }

    @Test
    func emLengthsOnTheRootUseTheInitialSize() throws {
        let svg = try parse(#"<rect width="2em" height="1em"/>"#, root: #"font-size="150%""#)
        let rect = try #require(svg.childElements.first as? DOM.Rect)
        #expect(rect.width == 48)
        #expect(rect.height == 24)
    }

    // MARK: - Helpers

    private func parse(_ body: String, root: String = "") throws -> DOM.SVG {
        try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" \#(root)>\#(body)</svg>"#)
    }

    private func makeLayer(_ body: String, root: String = "") throws -> LayerTree.Layer {
        LayerTree.Builder(svg: try parse(body, root: root)).makeLayer()
    }

    private func fontSize(of body: String, root: String = "") throws -> Float {
        let contents = try #require(try makeLayer(body, root: root).allContents.first)
        guard case .text(_, _, let attributes) = contents else {
            Issue.record("expected text, got \(contents)")
            return .nan
        }
        return attributes.size
    }
}

private extension LayerTree.Layer {

    /// The contents of this layer and its sublayers, depth first, excluding the sublayers themselves.
    var allContents: [Contents] {
        contents.flatMap { contents -> [Contents] in
            if case .layer(let l) = contents { return l.allContents }
            return [contents]
        }
    }
}
