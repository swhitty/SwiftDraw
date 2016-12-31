//
//  CharacterSet.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

struct CharacterSet {
    
    static var empty = CharacterSet()
    static var whitespaces: CharacterSet = " \t"
    static var whitespacesAndNewLines: CharacterSet = " \t\n\r"
    static var digits: CharacterSet = "0123456789"
    static var hexadecimal: CharacterSet = "0123456789ABCDEFabcdef"
    static var numeric: CharacterSet = "+-0123456789.Ee"
    
    private var storage = Set<Character>()
    
    mutating func insert(_ character: Character) {
        storage.insert(character)
    }
    
    mutating func insert(_ characters: Set<Character>) {
        for c in characters {
            storage.insert(c)
        }
    }
    
    mutating func insert(_ characters: String) {
        for c in characters.characters {
            storage.insert(c)
        }
    }
    
    func contains(_ character: Character) -> Bool {
        return storage.contains(character)
    }
}

extension CharacterSet: ExpressibleByStringLiteral {
    init(unicodeScalarLiteral value: String) {
        insert(value)
    }
    
    init(extendedGraphemeClusterLiteral value: String) {
        insert(value)
    }
    
    init(stringLiteral value: String) {
        insert(value)
    }
}
