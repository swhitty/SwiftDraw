//
//  LayerTree.FontFaceLocalTests.swift
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


#if canImport(CoreText)
@testable import SwiftDraw
@testable import SwiftDrawDOM
import CoreText
import Foundation
import Testing

struct LayerTreeFontFaceLocalTests {

    @Test(arguments: [("Helvetica-Bold", "Helvetica-Bold"), ("helvetica-bold", "Helvetica-Bold"),
                      ("Helvetica Light", "Helvetica-Light"), ("HELVETICA LIGHT", "Helvetica-Light")])
    func resolvesInstalledFontByPostScriptOrFullName(name: String, postScriptName: String) {
        #expect(CGProvider.installedFontPostScriptName(name) == postScriptName)
    }

    @Test
    func missingFontIsNotInstalled() {
        // CoreText substitutes Helvetica for an unknown name
        #expect(CGProvider.installedFontPostScriptName("No Such Font") == nil)
    }

    private func fonts(_ src: String) throws -> [LayerTree.TextAttributes.Font] {
        let svg = try DOM.SVG.parse(xml: """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><style>
          @font-face { font-family: 'F'; src: \(src); }
        </style></svg>
        """)
        return LayerTree.Builder(svg: svg).makeFonts(faceName: "F")
    }

    @Test
    func localFaceIsUsedWhenInstalled() throws {
        #expect(try fonts("local('Helvetica Light'), url(data:font/truetype;base64,AAAA) format('truetype')") == [.postScript("Helvetica-Light")])
    }

    @Test
    func missingLocalFallsBackToNextSource() throws {
        #expect(try fonts("local('No Such Font'), url(data:font/truetype;base64,AAAA) format('truetype')") == [.truetype(Data(base64Encoded: "AAAA")!)])
    }

    @Test
    func noLoadableSourceFallsBackToTheFamilyName() throws {
        // the renderer then moves on to the next family in font-family
        #expect(try fonts("local('No Such Font')") == [.name("F")])
    }

    @Test
    func localFaceIsNotReweighted() {
        let font = CGProvider.createCTFont(for: [.postScript("Helvetica-Light")], size: 12, weight: 700, isItalic: true)
        #expect(CTFontCopyPostScriptName(font) as String == "Helvetica-Light")
    }
}
#endif
