//
//  WOFF2Tests.swift
//  swift-woff2
//
//  Created by Simon Whitty on 7/2/26.
//  Copyright 2026 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-woff2
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

#if canImport(Compression)
import Foundation
import Testing
import CoreGraphics
import CoreText
import ImageIO
@testable import SwiftDraw

struct WOFF2Tests {

    @Test
    func bundle_loads_urls() {
        let url = Bundle.test.url(forResource: "Roboto-Regular.woff2", withExtension: nil)
        #expect(url != nil)
    }

    @Test
    func bundle_does_not_load_missing_urls() {
        let url = Bundle.test.url(forResource: "Missing.woff2", withExtension: nil)
        #expect(url == nil)
    }

    @Test
    func parses_WOFF2_from_Roboto() throws {
        let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.woff2"))
        
        #expect(woff2.header.numTables > 0)
        #expect(!woff2.tables.isEmpty)
        #expect(woff2.fontData.count > 0)
    }
    
    @Test
    func extracts_postscript_name_from_Roboto() throws {
        let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.woff2"))
        
        #expect(woff2.postScriptName == "RobotoRegular")
    }
    
    @Test
    func throws_on_invalid_data() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        
        #expect(throws: WOFF2Error.self) {
            try WOFF2(data: invalidData)
        }
    }
    
    @Test
    func throws_on_empty_data() {
        let emptyData = Data()
        
        #expect(throws: WOFF2Error.self) {
            try WOFF2(data: emptyData)
        }
    }
    
    @Test
    func makes_CGFont_from_Roboto_WOFF2() throws {
        let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.woff2"))
        let cgFont = try woff2.makeCGFont()
        
        #expect(cgFont.postScriptName == "RobotoRegular" as CFString)
    }
    
    @Test
    func makes_CGFont_from_Lato_WOFF2() throws {
        let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: "Lato-Regular.woff2"))
        let cgFont = try woff2.makeCGFont()
        
        #expect(cgFont.postScriptName == "Lato-Regular" as CFString)
    }
    
    @Test
    func makes_CGFont_from_SourceCodePro_WOFF2() throws {
        let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: "SourceCodePro-Regular.woff2"))
        let cgFont = try woff2.makeCGFont()
        
        #expect(cgFont.postScriptName == "SourceCodeProExtraLight-Regular" as CFString)
    }

    @Test
    func makes_CGFont_from_Roboto_Medium_Latin_WOFF2() throws {
        let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: "Roboto-Medium-Latin.woff2"))
        let cgFont = try woff2.makeCGFont()

        #expect(cgFont.postScriptName != nil)
    }

    @Test
    func generates_font_preview_PDF() throws {
        let woff2Fonts: [(filename: String, displayName: String)] = [
            ("Barrio-Regular.woff2", "Barrio"),
            ("EBGaramond-Regular.woff2", "EB Garamond"),
            ("Inter-Regular.woff2", "Inter"),

            ("PlaywriteUSTradGuides-Regular.woff2", "Playwrite US Trad"),
            ("Roboto-Regular.woff2", "Roboto"),
            ("Silkscreen-Regular.woff2", "Silkscreen"),
            ("SourceCodePro-Regular.woff2", "Source Code Pro"),
            ("VT323-Regular.woff2", "VT323")
        ]

        let sampleText = "The times they are a-changin'"
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("FontPreviews")
        try? FileManager.default.removeItem(at: outputDir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Build font entries with measured dimensions
        var fontEntries: [(displayName: String, ctFont: CTFont, textWidth: CGFloat, rowHeight: CGFloat)] = []
        for (filename, displayName) in woff2Fonts {
            let woff2 = try WOFF2(contentsOf: Bundle.test.url(forResource: filename))
            let cgFont = try woff2.makeCGFont()
            let ctFont = CTFontCreateWithGraphicsFont(cgFont, 48, nil, nil)
            let textWidth = measureTextWidth(text: sampleText, font: ctFont)
            let ascent = CTFontGetAscent(ctFont)
            let descent = CTFontGetDescent(ctFont)
            let rowHeight = max(ascent + descent + 30, 80)
            fontEntries.append((displayName, ctFont, textWidth, rowHeight))
        }

        // Calculate page size based on widest text and total height
        let maxTextWidth = fontEntries.map(\.textWidth).max() ?? 500
        let margin: CGFloat = 40
        let topPadding: CGFloat = 30
        let totalRowHeight = fontEntries.map(\.rowHeight).reduce(0, +)
        let pageWidth = ceil(maxTextWidth) + margin * 2
        let pageHeight = totalRowHeight + margin + topPadding

        let outputURL = outputDir.appendingPathComponent("FontPreviews.pdf")
        let pdfData = NSMutableData()

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return
        }

        pdfContext.beginPDFPage(nil)

        // White background
        pdfContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        pdfContext.fill(mediaBox)

        let grayColor = CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        let blackColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let labelFont = CTFontCreateWithName("Helvetica" as CFString, 12, nil)

        var yOffset = pageHeight - topPadding
        for entry in fontEntries {
            let descent = CTFontGetDescent(entry.ctFont)
            let baseline = yOffset - entry.rowHeight + descent + 20

            // Draw sample text
            let sampleAttributes: [CFString: Any] = [
                kCTFontAttributeName: entry.ctFont,
                kCTForegroundColorAttributeName: blackColor
            ]
            let sampleString = CFAttributedStringCreate(nil, sampleText as CFString, sampleAttributes as CFDictionary)!
            let sampleLine = CTLineCreateWithAttributedString(sampleString)
            pdfContext.textPosition = CGPoint(x: margin, y: baseline)
            CTLineDraw(sampleLine, pdfContext)

            // Draw font name label (below sample text)
            let labelAttributes: [CFString: Any] = [
                kCTFontAttributeName: labelFont,
                kCTForegroundColorAttributeName: grayColor
            ]
            let labelString = CFAttributedStringCreate(nil, entry.displayName as CFString, labelAttributes as CFDictionary)!
            let labelLine = CTLineCreateWithAttributedString(labelString)
            pdfContext.textPosition = CGPoint(x: margin, y: baseline - descent - 16)
            CTLineDraw(labelLine, pdfContext)

            yOffset -= entry.rowHeight
        }

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        try pdfData.write(to: outputURL, options: .atomic)
        print("Font preview PDF written to: \(outputURL.path)")
    }

    private func measureTextWidth(text: String, font: CTFont) -> CGFloat {
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        let attrString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrString)
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}
#endif
