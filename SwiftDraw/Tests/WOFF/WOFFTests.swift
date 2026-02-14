//
//  WOFFTests.swift
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
@testable import SwiftDraw

struct WOFFTests {

    @Test
    func parses_WOFF_from_Roboto() throws {
        let woff = try WOFF(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.woff"))
        
        #expect(woff.header.numTables > 0)
        #expect(!woff.tables.isEmpty)
        #expect(woff.fontData.count > 0)
    }
    
    @Test
    func extracts_postscript_name_from_Roboto_WOFF() throws {
        let woff = try WOFF(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.woff"))
        
        #expect(woff.postScriptName == "Roboto-Regular")
    }
    
    @Test
    func throws_on_invalid_data() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        
        #expect(throws: WOFFError.self) {
            try WOFF(data: invalidData)
        }
    }
    
    @Test
    func throws_on_empty_data() {
        let emptyData = Data()
        
        #expect(throws: WOFFError.self) {
            try WOFF(data: emptyData)
        }
    }
    
    @Test
    func makes_CGFont_from_Roboto_WOFF() throws {
        let woff = try WOFF(contentsOf: Bundle.test.url(forResource: "Roboto-Regular.woff"))
        let cgFont = try woff.makeCGFont()
        
        #expect(cgFont.postScriptName == "Roboto-Regular" as CFString)
    }
}
#endif
