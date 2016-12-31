//
//  Parser.XML.Color.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {

    func parseColor(data: String) throws -> DOM.Color {

        if let none = parseColorNone(data: data) {
            return none
        } else if let keyword = parseColorKeyword(data: data) {
            return .keyword(keyword)
        } else if let (r, g, b) = parseColorRGBi(data: data) {
            return .rgbi(r, g, b)
        } else if let (r, g, b) = parseColorRGBf(data: data) {
            return .rgbf(r, g, b)
        } else if let (r, g, b) = parseColorHex(data: data) {
            return .hex(r, g, b)
        }
        
        throw Error.invalid
    }

    func parseColorNone(data: String) -> DOM.Color? {
        if data == "none" {
            return .none
        }
        return nil
    }
    
    func parseColorKeyword(data: String) -> DOM.Color.Keyword? {
        return DOM.Color.Keyword(rawValue: data.trimmingCharacters(in: .whitespaces))
    }
    
    func parseColorRGBi(data: String) -> (UInt8, UInt8, UInt8)? {
        var scanner = ScannerB(text: data)

        guard let _ = scanner.scanFunction("rgb"),
              let r = scanner.scanUInt8(),
              let g = scanner.scanUInt8(),
              let b = scanner.scanUInt8() else {
            return nil
        }
        
        return (r, g, b)
    }
    
    func parseColorRGBf(data: String) -> (DOM.Float, DOM.Float, DOM.Float)? {
        var scanner = ScannerB(text: data)
        
        guard let _ = scanner.scanFunction("rgb"),
            let r = scanner.scanPercentage(),
            let g = scanner.scanPercentage(),
            let b = scanner.scanPercentage() else {
                return nil
        }
        
        return (r, g, b)
    }
    

    //#a5F should be parsed as #a050F0
    private func padHex(_ data: String) -> String? {
        let chars = data.unicodeScalars.map({$0})
        guard chars.count == 3 else { return data }

        return "\(chars[0])0\(chars[1])0\(chars[2])0)"
    }
    
    func parseColorHex(data: String) -> (UInt8, UInt8, UInt8)? {
        
        var scanner = ScannerB(text: data)
        
        guard let _ = scanner.scan("#"),
              let code = scanner.scan(scanner.hexadecimal),
              let paddedCode = padHex(code),
              let hex = UInt32(hex: paddedCode) else {
                return nil
            }
        
        let r = UInt8((hex >> 16) & 0xff)
        let g = UInt8((hex >> 8) & 0xff)
        let b = UInt8(hex & 0xff)

        return (r, g, b)
    }
}

extension UInt32 {
    init?(hex: String) {
        var val: UInt32 = 0
        guard Foundation.Scanner(string: hex).scanHexInt32(&val) else {
            return nil
        }
        self = val
    }
}
