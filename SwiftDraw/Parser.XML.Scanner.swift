//
//  XML.Parser.Scanner.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 2/11/18.
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
  
  struct Scanner {
    
    private let scanner: Foundation.Scanner
    var scanLocation: Int
    
    init(text: String) {
      self.scanner = Foundation.Scanner(string: text)
      self.scanLocation = self.scanner.scanLocation
      self.scanner.charactersToBeSkipped = Foundation.CharacterSet.whitespacesAndNewlines
    }
    
    var isEOF: Bool { return scanner.isAtEnd }
    
    @discardableResult
    mutating func scanString(_ token: String) throws -> Bool {
      return try self.scanString(matchingAny: [token]) == token
    }
    
    @discardableResult
    mutating func scanStringIfPossible(_ token: String) -> Bool {
      return (try? self.scanString(token)) == true
    }
    
    mutating func scanString(matchingAny tokens: Set<String>) throws -> String {
      scanner.scanLocation = scanLocation
      guard let match = tokens.first(where: { scanner.scanString($0, into: nil) }) else {
        throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return match
    }
    
    mutating func scanCase<T: RawRepresentable & CaseIterable>(from type: T.Type) throws -> T where T.RawValue == String {
      scanner.scanLocation = scanLocation
      
      guard let match = type.allCases.first(where: { scanner.scanString($0.rawValue, into: nil) }) else {
        throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return match
    }
    
    mutating func scanString(matchingAny characters: Foundation.CharacterSet) throws -> String {
      scanner.scanLocation = scanLocation
    #if os(Linux)
        var result: String?
    #else
        var result: NSString?
    #endif

      guard
        scanner.scanCharacters(from: characters, into: &result),
        let match = result.map({ $0 as String }),
        match.isEmpty == false else {
          throw Error.invalid
      }
      
      scanLocation = scanner.scanLocation
      return match
    }
    
    mutating func scanString(upTo token: String) throws -> String {
      scanner.scanLocation = scanLocation
    #if os(Linux)
        var result: String?
    #else
        var result: NSString?
    #endif
      guard
        scanner.scanUpTo(token, into: &result),
        let match = result.map({ $0 as String }) else {
          throw Error.invalid
      }
      
      scanLocation = scanner.scanLocation
      return match
    }
    
    mutating func scanCharacter(matchingAny characters: Foundation.CharacterSet) throws -> Character {
      let match = try scanString(matchingAny: characters)
      scanLocation = scanner.scanLocation - (match.count - 1)
      return match[match.startIndex]
    }
    
    mutating func scanUInt8() throws -> UInt8 {
      scanner.scanLocation = scanLocation
      var longVal: UInt64 = 0
      guard
        scanner.scanUnsignedLongLong(&longVal),
        let val = UInt8(exactly: longVal) else {
          throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return val
    }
    
    mutating func scanFloat() throws -> Float {
      scanner.scanLocation = scanLocation
      var val: Float = 0
      guard scanner.scanFloat(&val) else {
        throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return val
    }
    
    mutating func scanDouble() throws -> Double {
      scanner.scanLocation = scanLocation
      var val: Double = 0
      guard scanner.scanDouble(&val) else {
        throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return val
    }
    
    mutating func scanLength() throws -> DOM.Length {
      scanner.scanLocation = scanLocation
      var int64: Int64 = 0
      guard
        scanner.scanInt64(&int64),
        let val = DOM.Length(exactly: int64),
        val >= 0 else {
          throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return val
    }
    
    mutating func scanBool() throws -> Bool {
      return try self.scanCase(from: Boolean.self).boolValue
    }
    
    mutating func scanCoordinate() throws -> DOM.Coordinate {
      return DOM.Coordinate(try scanDouble())
    }
    
    mutating func scanPercentageFloat() throws -> Float {
      scanner.scanLocation = scanLocation
      let val = try scanFloat()
      guard val >= 0.0, val <= 1.0 else {
        throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return val
    }
    
    mutating func scanPercentage() throws -> Float {
      let initialLocation = scanLocation
      scanner.scanLocation = scanLocation
      
      let numeric = Foundation.CharacterSet(charactersIn: "+-0123456789.Ee")
      let numericString = try scanString(matchingAny: numeric)
      
      guard
        let val = Double(numericString),
        val >= 0, val <= 100,
        scanner.scanString("%", into: nil) || val == 0 else {
          scanLocation = initialLocation
          throw Error.invalid
      }
      scanLocation = scanner.scanLocation
      return Float(val / 100.0)
    }
  }
}

private enum Boolean: String, CaseIterable {
  case `true`
  case `false`
  case upperFalse = "FALSE"
  case upperTrue = "TRUE"
  case zero = "0"
  case one = "1"
  
  var boolValue: Bool {
    switch self {
    case .true, .upperTrue, .one:
      return true
    case .false, .upperFalse, .zero:
      return false
    }
  }
}

extension Scanner {
  
  enum Error: Swift.Error {
    case invalid
  }
  
  func scanBool() throws -> Bool {
    guard let match = Boolean.allCases.first(where: { self.scanString($0.rawValue, into: nil) }) else {
      throw Error.invalid
    }
    
    return match.boolValue
  }
  
  func scan(first set: Foundation.CharacterSet) -> UnicodeScalar? {
    #if os(Linux)
    var val: String?
    #else
    var val: NSString?
    #endif
    let start = scanLocation
    guard scanCharacters(from: set, into: &val),
      let string = val,
      string.length > 0 else {
        
        scanLocation = start
        return nil
    }
    
    if string.length > 1 {
      scanLocation -= (string.length - 1)
    }
    
    return UnicodeScalar(string.character(at: 0))
  }
  
  func scanCoordinate() throws -> DOM.Coordinate {
    var val: Double = 0
    guard scanDouble(&val) else { throw XMLParser.Error.invalid }
    return DOM.Coordinate(val)
  }
}
