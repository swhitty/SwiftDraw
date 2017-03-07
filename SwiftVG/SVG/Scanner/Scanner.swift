//
//  Scanner.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

struct Scanner {
    typealias CharacterSet = SwiftVG.CharacterSet
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
    
    func index(after startIndex: Index, charset: CharacterSet) -> Index {
        var idx = startIndex
        
        while idx != characters.endIndex,
            charset.contains(characters[idx]) {
            idx = characters.index(after: idx)
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
    
    mutating func scanCoordinate() throws -> DOM.Coordinate {
        return try scan(any: CharacterSet.numeric) { return DOM.Coordinate($0) }
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
