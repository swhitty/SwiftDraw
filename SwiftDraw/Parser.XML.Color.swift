//
//  Parser.XML.Color.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
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
import Foundation

extension XMLParser {
  
  func parseFill(_ data: String) throws -> DOM.Fill {
    if let c = try parseColorRGB(data: data) {
      return .color(c)
    } else if let c = try parseColorHex(data: data) {
      return .color(c)
    } else if let c = try parseColorP3(data: data) {
      return .color(c)
    } else if let c = parseColorKeyword(data: data) {
      return .color(c)
    } else if let c = parseColorNone(data: data) {
      return .color(c)
    } else if let c = parseColorNone(data: data) {
      return .color(c)
    } else if let url = try parseURLSelector(data: data) {
      return .url(url)
    }
    
    throw Error.invalid
  }
  
  private func parseColorNone(data: String) -> DOM.Color? {
    if data.trimmingCharacters(in: .whitespaces) == "none" {
      return DOM.Color.none // .none resolves to Optional.none
    }
    return nil
  }
  
  private func parseColorKeyword(data: String) -> DOM.Color? {
    let raw = data.trimmingCharacters(in: .whitespaces)
    guard let keyword = DOM.Color.Keyword(rawValue: raw) else {
      return nil
    }
    return .keyword(keyword)
  }
  
  private func parseColorRGB(data: String) throws -> DOM.Color? {
    var scanner = XMLParser.Scanner(text: data)
    guard scanner.scanStringIfPossible("rgb(") else { return nil }
    
    if let c = try? parseColorRGBf(data: data) {
      return c
    }
    
    return try parseColorRGBi(data: data)
  }
  
  private func parseURLSelector(data: String) throws -> DOM.URL? {
    var scanner = XMLParser.Scanner(text: data)
    guard (try? scanner.scanString("url(")) == true else {
      return nil
    }
    
    let urlText = try scanner.scanString(upTo: ")")
    _ = try? scanner.scanString(")")
    
    let urlTrimmed = urlText.trimmingCharacters(in: .whitespaces)
    
    guard scanner.isEOF, let url = URL(string: urlTrimmed) else {
      throw XMLParser.Error.invalid
    }
    
    return url
  }
  
  private func parseColorRGBi(data: String) throws -> DOM.Color {
    var scanner = XMLParser.Scanner(text: data)
    try scanner.scanString("rgb(")
    
    let r = try scanner.scanUInt8()
    scanner.scanStringIfPossible(",")
    let g = try scanner.scanUInt8()
    scanner.scanStringIfPossible(",")
    let b = try scanner.scanUInt8()
    try scanner.scanString(")")
    return .rgbi(r, g, b)
  }
  
  private func parseColorRGBf(data: String) throws -> DOM.Color {
    var scanner = XMLParser.Scanner(text: data)
    try scanner.scanString("rgb(")
    
    let r = try scanner.scanPercentage()
    scanner.scanStringIfPossible(",")
    let g = try scanner.scanPercentage()
    scanner.scanStringIfPossible(",")
    let b = try scanner.scanPercentage()
    try scanner.scanString(")")
    
    return .rgbf(r, g, b)
  }
  
  private func parseColorP3(data: String) throws -> DOM.Color? {
    var scanner = XMLParser.Scanner(text: data)
    guard scanner.scanStringIfPossible("color(display-p3") else { return nil }

    let r = try scanner.scanFloat()
    scanner.scanStringIfPossible(",")
    let g = try scanner.scanFloat()
    scanner.scanStringIfPossible(",")
    let b = try scanner.scanFloat()
    try scanner.scanString(")")

    return .p3(r, g, b)
  }
  
  // #a5F should be parsed as #a050F0
  private func padHex(_ data: String) -> String? {
    let chars = data.unicodeScalars.map({ $0 })
    guard chars.count == 3 else { return data }
    
    return "\(chars[0])0\(chars[1])0\(chars[2])0"
  }
  
  private func parseColorHex(data: String) throws -> DOM.Color? {
    var scanner = XMLParser.Scanner(text: data)
    guard scanner.scanStringIfPossible("#") else { return nil }
    let hexadecimal = Foundation.CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
    let code = try scanner.scanString(matchingAny: hexadecimal)
    guard
      let paddedCode = padHex(code),
      let hex = Int(paddedCode, radix: 16) else {
        throw Error.invalid
    }
    
    let r = UInt8((hex >> 16) & 0xff)
    let g = UInt8((hex >> 8) & 0xff)
    let b = UInt8(hex & 0xff)
    
    return .hex(r, g, b)
  }
}
