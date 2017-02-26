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
        
        if let c = try parseColorRGB(data: data) {
            return c
        } else if let c = try parseColorHex(data: data) {
            return c
        } else if let c = parseColorKeyword(data: data) {
            return c
        } else if let c = parseColorNone(data: data) {
            return c
        }
        
        throw Error.invalid
    }
    
    func parseColorNone(data: String) -> DOM.Color? {
        if data.trimmingCharacters(in: .whitespaces) == "none" {
            return DOM.Color.none // .none resolves to Optional.none
        }
        return nil
    }
    
    func parseColorKeyword(data: String) -> DOM.Color? {
        let raw = data.trimmingCharacters(in: .whitespaces)
        guard let keyword = DOM.Color.Keyword(rawValue: raw) else {
            return nil
        }
        return .keyword(keyword)
    }
    
    func parseColorRGB(data: String) throws -> DOM.Color? {
        var scanner = Scanner(text: data)
        guard scanner.scan("rgb(") != nil else { return nil }
        
        if let c = try? parseColorRGBf(data: data) {
            return c
        }
        
        return try parseColorRGBi(data: data)
    }
    
    func parseColorRGBi(data: String) throws -> DOM.Color {
        var scanner = Scanner(text: data)
        guard scanner.scan("rgb(") != nil else { throw Error.invalid }
        let r = try scanner.scanUInt8()
        _ = scanner.scan(",")
        let g = try scanner.scanUInt8()
        _ = scanner.scan(",")
        let b = try scanner.scanUInt8()
        guard scanner.scan(")") != nil else { throw Error.invalid }
        return .rgbi(r, g, b)
    }
    
    func parseColorRGBf(data: String) throws -> DOM.Color {
        var scanner = Scanner(text: data)
        guard scanner.scan("rgb(") != nil else { throw Error.invalid }
        let r = try scanner.scanPercentage()
        _ = scanner.scan(",")
        let g = try scanner.scanPercentage()
        _ = scanner.scan(",")
        let b = try scanner.scanPercentage()
        guard scanner.scan(")") != nil else { throw Error.invalid }
        return .rgbf(r, g, b)
    }
    
    // #a5F should be parsed as #a050F0
    private func padHex(_ data: String) -> String? {
        let chars = data.unicodeScalars.map({ $0 })
        guard chars.count == 3 else { return data }
        
        return "\(chars[0])0\(chars[1])0\(chars[2])0)"
    }
    
    func parseColorHex(data: String) throws -> DOM.Color? {
        var scanner = Scanner(text: data)
        guard scanner.scan("#") != nil else { return nil }
        
        guard let code = scanner.scan(any: CharacterSet.hexadecimal),
            let paddedCode = padHex(code),
            let hex = UInt32(hex: paddedCode) else {
            throw Error.invalid
        }
        
        let r = UInt8((hex >> 16) & 0xff)
        let g = UInt8((hex >> 8) & 0xff)
        let b = UInt8(hex & 0xff)
        
        return .hex(r, g, b)
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
