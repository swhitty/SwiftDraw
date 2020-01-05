//
//  Parser.XML.swift
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

struct XMLParser {
  enum Error: Swift.Error {
    case invalid
    case missingAttribute(name: String)
    case invalidAttribute(name: String, value: Any)
    case invalidElement(name: String, error: Swift.Error, line: Int?, column: Int?)
  }
  
  var options: Options = []
  
  struct Options: OptionSet {
    let rawValue: Int
    init(rawValue: Int) {
      self.rawValue = rawValue
    }
    
    static let skipInvalidAttributes = Options(rawValue: 1)
    static let skipInvalidElements = Options(rawValue: 2)
  }
}

protocol AttributeValueParser {
  func parseFloat(_ value: String) throws -> DOM.Float
  func parseFloats(_ value: String) throws -> [DOM.Float]
  func parsePercentage(_ value: String) throws -> DOM.Float
  func parseCoordinate(_ value: String) throws -> DOM.Coordinate
  func parseLength(_ value: String) throws -> DOM.Length
  func parseBool(_ value: String) throws -> DOM.Bool
  func parseFill(_ value: String) throws -> DOM.Fill
  func parseUrl(_ value: String) throws -> DOM.URL
  func parseUrlSelector(_ value: String) throws -> DOM.URL
  func parsePoints(_ value: String) throws -> [DOM.Point]
  
  func parseRaw<T: RawRepresentable>(_ value: String) throws -> T where T.RawValue == String
}

protocol AttributeParser {
  var parser: AttributeValueParser { get }
  var options: XMLParser.Options { get }
  
  // either parse and return T or
  // throw Error.missingAttribute when key cannot resolve to a value
  // throw Error.invalidAttribute when value cannot be parsed into T
  func parse<T>(_ key: String, _ exp: (String) throws -> T) throws -> T
}

extension AttributeParser {
  
  func parseString(_ key: String) throws -> String {
    return try parse(key) { $0 }
  }
  
  func parseFloat(_ key: String) throws -> DOM.Float {
    return try parse(key) { return try parser.parseFloat($0) }
  }
  
  func parseFloats(_ key: String) throws -> [DOM.Float] {
    return try parse(key) { return try parser.parseFloats($0) }
  }
  
  func parsePercentage(_ key: String) throws -> DOM.Float {
    return try parse(key) { return try parser.parsePercentage($0) }
  }
  
  func parseCoordinate(_ key: String) throws -> DOM.Coordinate {
    return try parse(key) { return try parser.parseCoordinate($0) }
  }
  
  func parseLength(_ key: String) throws -> DOM.Length {
    return try parse(key) { return try parser.parseLength($0) }
  }
  
  func parseBool(_ key: String) throws -> DOM.Bool {
    return try parse(key) { return try parser.parseBool($0) }
  }
  
  func parseFill(_ key: String) throws -> DOM.Fill {
    return try parse(key) { return try parser.parseFill($0) }
  }
  
  func parseColor(_ key: String) throws -> DOM.Color {
    return try parseFill(key).getColor()
  }
  
  func parseUrl(_ key: String) throws -> DOM.URL {
    return try parse(key) { return try parser.parseUrl($0) }
  }
  
  func parseUrlSelector(_ key: String) throws -> DOM.URL {
    return try parse(key) { return try parser.parseUrlSelector($0) }
  }
  
  func parsePoints(_ key: String) throws -> [DOM.Point] {
    return try parse(key) { return try parser.parsePoints($0) }
  }
  
  func parseRaw<T: RawRepresentable>(_ key: String) throws -> T where T.RawValue == String {
    return try parse(key) { return try parser.parseRaw($0) }
  }
}

extension AttributeParser {
  
  typealias Options = XMLParser.Options
  
  func parse<T>(_ key: String, exp: (String) throws -> T) throws -> T? {
    do {
      return try parse(key, exp)
    } catch XMLParser.Error.missingAttribute(_) {
      return nil
    }  catch let error {
      guard options.contains(.skipInvalidAttributes) else { throw error }
    }
    return nil
  }
  
  func parseString(_ key: String) throws -> String? {
    return try parse(key) { $0 }
  }
  
  func parseFloat(_ key: String) throws -> DOM.Float? {
    return try parse(key) { return try parser.parseFloat($0) }
  }
  
  func parseFloats(_ key: String) throws -> [DOM.Float]? {
    return try parse(key) { return try parser.parseFloats($0) }
  }
  
  func parsePercentage(_ key: String) throws -> DOM.Float? {
    return try parse(key) { return try parser.parsePercentage($0) }
  }
  
  func parseCoordinate(_ key: String) throws -> DOM.Coordinate? {
    return try parse(key) { return try parser.parseCoordinate($0) }
  }
  
  func parseLength(_ key: String) throws -> DOM.Length? {
    return try parse(key) { return try parser.parseLength($0) }
  }
  
  func parseBool(_ key: String) throws -> DOM.Bool? {
    return try parse(key) { return try parser.parseBool($0) }
  }
  
  func parseFill(_ key: String) throws -> DOM.Fill? {
    return try parse(key) { return try parser.parseFill($0) }
  }
  
  func parseColor(_ key: String) throws -> DOM.Color? {
    return try parseFill(key)?.getColor()
  }
  
  func parseUrl(_ key: String) throws -> DOM.URL? {
    return try parse(key) { return try parser.parseUrl($0) }
  }
  
  func parseUrlSelector(_ key: String) throws -> DOM.URL? {
    return try parse(key) { return try parser.parseUrlSelector($0) }
  }
  
  func parsePoints(_ key: String) throws -> [DOM.Point]? {
    return try parse(key) { return try parser.parsePoints($0) }
  }
  
  func parseRaw<T: RawRepresentable>(_ key: String) throws -> T? where T.RawValue == String {
    return try parse(key) { return try parser.parseRaw($0) }
  }
}
