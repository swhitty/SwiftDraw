//
//  Scanner.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

struct Scanner {
    typealias CharacterSet = SwiftDraw.CharacterSet
    typealias Index = String.CharacterView.Index
    
    let characters: String.CharacterView
    var index: Index
    
    var precedingCharactersToSkip: CharacterSet? = CharacterSet.whitespaces
    
    var isEOF: Bool {
        // are there any more chars to scan?
        let idx = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        return idx == characters.endIndex
    }
    
    init(text: String) {
        characters = text.characters
        index = characters.startIndex
    }
    
    func index(after startIndex: Index, charset: CharacterSet, max: Int = Int.max) -> Index {
        var idx = startIndex
        var count = 0
        
        while idx != characters.endIndex,
              count < max,
              charset.contains(characters[idx]) {
            idx = characters.index(after: idx)
            count += 1
        }
        
        return idx
    }
    
    func index(after startIndex: Index, until charset: CharacterSet) -> Index {
        var idx = startIndex
        
        while idx != characters.endIndex,
            charset.contains(characters[idx]) == false {
            idx = characters.index(after: idx)
        }
        
        return idx
    }
    
    mutating func scan(any charset: CharacterSet) -> String? {
        let start = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        let end = index(after: start, charset: charset)
        
        guard end > start else {
            return nil
        }
        
        index = end
        return String(characters[start..<end])
    }
    
    mutating func scan(optional prefix: CharacterSet, any charset: CharacterSet) -> String? {
        let start = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        let prefixEnd = index(after: start, charset: prefix)
        let end = index(after: prefixEnd, charset: charset)
        
        guard end > start else {
            return nil
        }
        
        index = end
        return String(characters[start..<end])
    }
    
    mutating func scan(first charset: CharacterSet) -> Character? {
        let idx = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        
        guard idx != characters.endIndex,
            charset.contains(characters[idx]) else {
            return nil
        }
        
        let c = characters[idx]
        index = characters.index(after: idx)
        return c
    }
    
    mutating func scan(_ string: String) -> String? {
        let matchChars = string.characters
        
        var idxA = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        var idxB = matchChars.startIndex
        
        while idxA != characters.endIndex,
            idxB != matchChars.endIndex,
            matchChars[idxB] == characters[idxA] {
            
            idxA = characters.index(after: idxA)
            idxB = matchChars.index(after: idxB)
        }
        
        // idxB == endIndex if all chars have matched
        guard idxB == matchChars.endIndex else {
            return nil
        }
        
        index = idxA
        return string
    }
    
    mutating func scan(upTo charset: CharacterSet, orEOF: Bool = false) -> String? {
        let start = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        let end = index(after: start, until: charset)
        
        guard end > start,
              (orEOF || end != characters.endIndex) else {
            return nil
        }
        
        index = end
        return String(characters[start..<end])
    }
    
    mutating func scanToEOF() -> String? {
        let start = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        let end = characters.endIndex
        
        guard end > start else {
            return nil
        }
        
        index = end
        return String(characters[start..<end])
    }
}

extension Scanner {
    
    enum Error: Swift.Error {
        case invalid
    }
    
    mutating func scan<T>(any charset: CharacterSet, parser: (String) -> T?) throws -> T {
        let start = index
        guard let text = scan(any: charset),
            let val = parser(text) else {
            index = start
            throw Error.invalid
        }
        return val
    }
    
    mutating func scanUInt8() throws -> UInt8 {
        return try scan(any: CharacterSet.digits) { return UInt8($0) }
    }
    
    mutating func scanFloat() throws -> Float {
        return try scan(any: CharacterSet.numeric) { return Float($0) }
    }
    
    mutating func scanDouble() throws -> Double {
        return try scan(any: CharacterSet.numeric) { return Double($0) }
    }
    
    mutating func scanBool() throws -> Bool {
        return try scan(any: "trueTRUEfalseFALSE01") {
            switch $0.lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        }
    }
    
    mutating func scanCoordinateA() throws -> DOM.Coordinate {
        let start = index
        guard let text = scan(optional: CharacterSet.sign,
                                   any: CharacterSet.coordValue),
              let val = DOM.Coordinate(text) else {
                index = start
                throw Error.invalid
        }
        return val
    }
    
        
    mutating func scanCoordinate() throws -> DOM.Coordinate {
        
        let start = index(after: index, charset: precedingCharactersToSkip ?? CharacterSet.empty)
        
        var end = index(after: start, charset: CharacterSet.sign, max: 1)
        end = index(after: end, charset: CharacterSet.digits)
        end = index(after: end, charset: ".", max: 1)
        end = index(after: end, charset: CharacterSet.digits)
        let eIndex = index(after: end, charset: "eE", max: 1)
        if eIndex > end {
            end = index(after: eIndex, charset: CharacterSet.sign, max: 1)
            end = index(after: end, charset: CharacterSet.digits)
        }

        guard end > start else { throw Error.invalid }
        
        let text = String(characters[start..<end])
        
        guard let val = DOM.Coordinate(text) else {
            throw Error.invalid
        }
        
        index = end
        return val
    }
    
    
    mutating func scanLength() throws -> DOM.Length {
        return try scan(any: CharacterSet.digits) { return DOM.Length($0) }
    }
    
    mutating func scanPercentageFloat() throws -> Float {
        let start = index
        guard let text = scan(any: CharacterSet.numeric),
            let val = Float(text),
            val >= 0.0, val <= 1.0 else {
                index = start
                throw Error.invalid
        }
        
        return val
    }
    
    mutating func scanPercentage() throws -> Float {
        let start = index
        guard let text = scan(any: CharacterSet.numeric),
              let val = Double(text),
              val >= 0, val <= 100 else {
            index = start
            throw Error.invalid
        }
        
        guard scan("%") != nil || val == 0 else {
            index = start
            throw Error.invalid
        }

        return Float(val / 100.0)
    }
}

struct CharSet {
    static var commandSet = Foundation.CharacterSet(charactersIn: "MmLlHhVvCcSsQqTtAaZz")
    static var delimeter = Foundation.CharacterSet(charactersIn: ",;")
    static var boolInt = Foundation.CharacterSet(charactersIn: "10")
}

extension Foundation.Scanner {

    convenience init(text: String) {
        self.init(string: text)
    }
    
    var isEOF: Bool { return isAtEnd }
    
    func scan(first set: Foundation.CharacterSet) -> UnicodeScalar? {
        var val: NSString?
        let start = scanLocation
        guard scanCharacters(from: set, into: &val),
              let string = val,
              string.length > 0 else {
            
            scanLocation = start
            return nil
        }
        
        return UnicodeScalar(string.character(at: 0))
    }
    
    func scanBool() throws -> DOM.Bool {
        guard let scalar = scan(first: CharSet.boolInt) else {
            throw XMLParser.Error.invalid
        }
        return scalar == UnicodeScalar("1") ? true : false
    }
    
    func scanCoordinate() throws -> DOM.Coordinate {
        var val: Double = 0
        guard scanDouble(&val) else { throw XMLParser.Error.invalid }
        return DOM.Coordinate(val)
    }
    
    
}
