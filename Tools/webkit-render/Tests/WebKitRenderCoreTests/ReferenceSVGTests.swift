import Foundation
import Testing
@testable import WebKitRenderCore

struct ReferenceSVGTests {

    private func prepared(_ svg: String, fontSmoothing: Bool = false) -> String {
        String(decoding: ReferenceSVG.prepare(Data(svg.utf8), fontSmoothing: fontSmoothing), as: UTF8.self)
    }

    private let style = ReferenceSVG.disableFontSmoothing

    @Test
    func insertsStyleAfterRootTag() {
        #expect(prepared(#"<svg width="10"><rect/></svg>"#) == #"<svg width="10">\#(style)<rect/></svg>"#)
    }

    @Test
    func fontSmoothingKeepsData() {
        let svg = #"<svg width="10"><rect/></svg>"#
        #expect(prepared(svg, fontSmoothing: true) == svg)
    }

    @Test
    func skipsDeclarationCommentsAndDoctype() {
        let svg = #"""
        <?xml version="1.0"?><!-- <svg> in a comment --><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "x.dtd"><svg><g/></svg>
        """#
        #expect(prepared(svg).hasSuffix("<svg>\(style)<g/></svg>"))
    }

    @Test
    func ignoresGreaterThanInAttributes() {
        #expect(prepared(#"<svg data-x="a>b" data-y='c>d'><g/></svg>"#) == #"<svg data-x="a>b" data-y='c>d'>\#(style)<g/></svg>"#)
    }

    @Test
    func prefixedRoot() {
        #expect(prepared(#"<s:svg xmlns:s="http://www.w3.org/2000/svg"><s:g/></s:svg>"#)
            == #"<s:svg xmlns:s="http://www.w3.org/2000/svg">\#(style)<s:g/></s:svg>"#)
    }

    @Test(arguments: [
        #"<svg width="10"/>"#,        // self-closing root: nothing to put text in
        #"<html><svg/></html>"#,      // not an SVG root
        #"<svg width="10""#,          // unterminated
        "",
    ])
    func leavesUnchanged(_ svg: String) {
        #expect(prepared(svg) == svg)
    }

    @Test
    func leavesNonUTF8Unchanged() {
        let data = Data([0xFF, 0xFE, 0x3C, 0x00])
        #expect(ReferenceSVG.prepare(data, fontSmoothing: false) == data)
    }
}
