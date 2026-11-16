//
//  Parser.FuncIRIAndStyleCommentTests.swift
//  SwiftDraw
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//

@testable import SwiftDrawDOM
import Foundation
import Testing

/// CSS `url()` may hold a quoted string and whitespace; `style=""` may hold comments.
struct ParserFuncIRIAndStyleCommentTests {

    private func attributes(_ rect: String, styles: String = "") throws -> DOM.PresentationAttributes {
        let svg = try DOM.SVG.parse(xml: #"<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">\#(styles)\#(rect)</svg>"#)
        let element = try #require(svg.childElements.last)
        return DOM.presentationAttributes(for: element, styles: svg.styles)
    }

    static let quotedURLs = [
        "url(#a)",
        "url('#a')",
        ##"url("#a")"##,
        "url( #a )",
        "url(  '#a'  )",
        ##"url( "#a")"##
    ]

    @Test(arguments: quotedURLs)
    func fillAttribute(_ value: String) throws {
        let att = try attributes("<rect width='1' height='1' fill='\(value.replacingOccurrences(of: "'", with: "&apos;"))' />")
        #expect(att.fill == .url(URL(string: "#a")!))
    }

    @Test(arguments: quotedURLs)
    func everyFuncIRIProperty(_ value: String) throws {
        let style = "fill:\(value);stroke:\(value);clip-path:\(value);mask:\(value);filter:\(value);marker-start:\(value);marker-mid:\(value);marker-end:\(value)"
        let att = try attributes(#"<rect width="1" height="1" style="\#(style.replacingOccurrences(of: "\"", with: "&quot;"))" />"#)
        let url = URL(string: "#a")!
        #expect(att.fill == .url(url))
        #expect(att.stroke == .url(url))
        #expect(att.clipPath == url)
        #expect(att.mask == url)
        #expect(att.filter == [.url(url)])
        #expect(att.markerStart == url)
        #expect(att.markerMid == url)
        #expect(att.markerEnd == url)
    }

    @Test(arguments: quotedURLs)
    func clipPathAndMaskAttributes(_ value: String) throws {
        let escaped = value.replacingOccurrences(of: "'", with: "&apos;")
        let att = try attributes("<rect width='1' height='1' clip-path='\(escaped)' mask='\(escaped)' marker-end='\(escaped)' />")
        #expect(att.clipPath == URL(string: "#a")!)
        #expect(att.mask == URL(string: "#a")!)
        #expect(att.markerEnd == URL(string: "#a")!)
    }

    @Test
    func quotedURLInStyleSheet() throws {
        let att = try attributes(
            #"<rect class="r" width="1" height="1" />"#,
            styles: ##"<style>.r { fill: url('#a'); stroke: url( "#b" ) }</style>"##
        )
        #expect(att.fill == .url(URL(string: "#a")!))
        #expect(att.stroke == .url(URL(string: "#b")!))
    }

    @Test
    func quotedURLWithFallback() throws {
        #expect(try XMLParser().parseFill("url('#g') red") == .urlWithFallback(URL(string: "#g")!, .keyword(.red)))
        #expect(try XMLParser().parseFill(##"url( "#g" ) none"##) == .urlWithFallback(URL(string: "#g")!, .none))
        let att = try attributes(#"<rect width="1" height="1" fill="url('#g') #ff0000" />"#)
        #expect(att.fill == .urlWithFallback(URL(string: "#g")!, .hex(255, 0, 0)))
    }

    @Test(arguments: [
        "/*text*/fill:green/*text*/",
        "fill:/* a; b */green",
        "fill/**/:green",
        "/* x */ fill: green; /* stroke: red; */",
        "fill:green;/* unterminated",
        "/*a*//*b*/fill:green"
    ])
    func commentsInStyleAttribute(_ style: String) throws {
        let att = try attributes(#"<rect width="1" height="1" style="\#(style)" />"#)
        #expect(att.fill == .color(.keyword(.green)))
        #expect(att.stroke == nil)
    }

    @Test
    func commentsInStyleAttributeDictionary() throws {
        let style = try XMLParser().parseStyleAttributes("/*text*/fill:green/*text*/; /* stroke:red */ opacity: 0.5")
        #expect(style == ["fill": "green", "opacity": "0.5"])
    }
}
