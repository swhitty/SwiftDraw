//
//  Scanner.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation


struct ScannerB {
    
    typealias Index = String.CharacterView.Index
    let characters: String.CharacterView
    var index: Index
    
    init(text: String) {
        characters = text.characters
        index = characters.startIndex
    }
    
    let whitespace: Set<Character> = [" ", "\t"]
    let intDigits: Set<Character> = ["0","1","2","3","4","5","6","7","8","9"]
    let digits: Set<Character> = ["0","1","2","3","4","5","6","7","8","9",".", "-", "E", "e"]
    let hexadecimal: Set<Character> = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","a","b","c","d","e","f"]
    
    mutating func scan(_ charset: Set<Character>) -> String? {
        let start = index
        var end = start
        
        while end != characters.endIndex,
              charset.contains(characters[end]) {
                end = characters.index(after: end)
        }
        
        guard end > start else {
            return nil
        }
        
        index = end
        return String(characters[start..<end])
    }
    
    
    mutating func scan(_ string: String) -> String? {
        let matchChars = string.characters
        
        var idxA = index
        var idxB = matchChars.startIndex
    
        while idxA != characters.endIndex,
              idxB != matchChars.endIndex,
              matchChars[idxB] == characters[idxA] {
                
                idxA = characters.index(after: idxA)
                idxB = matchChars.index(after: idxB)
        }
        
        //idxB will only be andIdex if all chars have matched
        guard idxB == matchChars.endIndex else {
            return nil
        }
        
        index = idxA
        return string
    }
    
    mutating func scan(any strings: Set<String>) -> String? {
        for s in strings {
            if let match = scan(s) {
                return match
            }
        }
        return nil
    }
    
    mutating func scanCharacter(_ charset: Set<Character>) -> Character? {
        guard index != characters.endIndex,
              charset.contains(characters[index]) else {
                return nil
        }
        
        let c = characters[index]
        index = characters.index(after: index)
        return c
    }

    mutating func scanCoordinate() -> DOM.Coordinate? {
        let start = index
        _ = scan(whitespace)
        
        guard let digits = scan(digits),
              let cordinate = DOM.Coordinate(digits) else {
                index = start
                return nil
        }
        
        _ = scan(whitespace)
        _ = scan(";")

        return cordinate
    }
    
    mutating func scanBool() -> DOM.Bool? {
        let start = index
        _ = scan(whitespace)
        
        guard let digits = scan(["0", "1"]) else {
            index = start
            return nil
        }
        
        _ = scan(whitespace)
        _ = scan(";")
        
        return digits == "1"
    }
    
    mutating func scanUInt8() -> UInt8? {
        
        let start = index
        _ = scan(whitespace)
        
        guard let digits = scan(intDigits),
              let val = UInt8(digits) else {
                index = start
                return nil
        }
        
        _ = scan(whitespace)
        _ = scan(",")
        
        return val
    }
    
    mutating func scanPercentage() -> Float? {
        
        let start = index
        _ = scan(whitespace)
        
        guard let digits = scan(digits),
                let val = Double(digits),
                val >= 0, val <= 100 else {
                index = start
                return nil
        }
        
        _ = scan(whitespace)
        guard scan("%") != nil || val == 0 else {
            index = start
            return nil
        }
        
        _ = scan(whitespace)
        _ = scan(",")
        
        return Float(val/100.0)
    }
    
    // Scan any function eg;
    // rgb  for   rgb(0,1,2)
    // hsl  for   hsl(0,1,2)
    mutating func scanFunction(_ name: String) -> String? {
        let start = index
        _ = scan(whitespace)
        
        guard let _ = scan(name) else {
            index = start
            return nil
        }
        _ = scan(whitespace)
        guard let _ = scan("(") else {
            index = start
            return nil
        }
        
        return name
    }
}




