//
//  TTFTests.swift
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

import Foundation
import Testing
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import SwiftDraw

struct TTFTests {

    @Test
    func parses_TTF_from_Roboto() throws {
        let ttf = try TTF(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.ttf"))
        
        #expect(ttf.header.numTables > 0)
        #expect(!ttf.tables.isEmpty)
        #expect(ttf.fontData.count > 0)
    }
    
    @Test
    func extracts_postscript_name_from_Roboto_TTF() throws {
        let ttf = try TTF(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.ttf"))
        
        #expect(ttf.postScriptName == "RobotoRegular")
    }
    
    @Test
    func parses_OTF_from_SourceCodePro() throws {
        let otf = try TTF(contentsOf: Bundle.test.url(forResource: "SourceCodePro-Regular.otf"))
        
        #expect(otf.header.sfntVersion == 0x4F54544F) // "OTTO"
        #expect(otf.header.numTables > 0)
        #expect(!otf.tables.isEmpty)
    }
    
    @Test
    func extracts_postscript_name_from_SourceCodePro_OTF() throws {
        let otf = try TTF(contentsOf: Bundle.test.url(forResource: "SourceCodePro-Regular.otf"))
        
        #expect(otf.postScriptName == "SourceCodePro-Regular")
    }
    
    @Test
    func throws_on_invalid_data() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        
        #expect(throws: TTFError.self) {
            try TTF(data: invalidData)
        }
    }
    
    @Test
    func throws_on_empty_data() {
        let emptyData = Data()
        
        #expect(throws: TTFError.self) {
            try TTF(data: emptyData)
        }
    }

#if canImport(CoreGraphics)
    @Test
    func makes_CGFont_from_Roboto_TTF() throws {
        let ttf = try TTF(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.ttf"))
        let cgFont = try ttf.makeCGFont()
        
        #expect(cgFont.postScriptName == "RobotoRegular" as CFString)
    }
    
    @Test
    func makes_CGFont_from_SourceCodePro_OTF() throws {
        let ttf = try TTF(contentsOf: Bundle.test.url(forResource: "SourceCodePro-Regular.otf"))
        let cgFont = try ttf.makeCGFont()
        
        #expect(cgFont.postScriptName == "SourceCodePro-Regular" as CFString)
    }
#endif
}
