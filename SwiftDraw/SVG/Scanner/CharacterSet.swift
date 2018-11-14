//
//  CharacterSet.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2016 Simon Whitty
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

struct CharacterSet {
    
    static var empty = CharacterSet()
    static var whitespaces: CharacterSet = " \t"
    static var whitespacesAndNewLines: CharacterSet = " \t\n\r"
    static var digits: CharacterSet = "0123456789"
    static var hexadecimal: CharacterSet = "0123456789ABCDEFabcdef"
    static var numeric: CharacterSet = "+-0123456789.Ee"
    static var sign: CharacterSet = "+-"
    static var coordValue: CharacterSet = "0123456789.Ee"
    
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

struct CharSet {
    static var commandSet = Foundation.CharacterSet(charactersIn: "MmLlHhVvCcSsQqTtAaZz")
    static var delimeter = Foundation.CharacterSet(charactersIn: ",;")
    static var boolInt = Foundation.CharacterSet(charactersIn: "10")
}

