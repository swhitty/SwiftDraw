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
        var currentIndex: String.Index

        init(text: String) {
            self.scanner = Foundation.Scanner(string: text)
            self.currentIndex = self.scanner.currentIndex
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
            scanner.currentIndex = currentIndex
            guard let match = tokens.first(where: { scanner.scanString($0) != nil }) else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return match
        }
        
        mutating func scanCase<T: RawRepresentable & CaseIterable>(from type: T.Type) throws -> T where T.RawValue == String {
            scanner.currentIndex = currentIndex
            
            guard let match = type.allCases.first(where: { scanner.scanString($0.rawValue) != nil }) else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return match
        }
        
        mutating func scanString(matchingAny characters: Foundation.CharacterSet) throws -> String {
            scanner.currentIndex = currentIndex
            guard
                let match = scanner.scanCharacters(from: characters),
                match.isEmpty == false else {
                throw Error.invalid
            }
            
            currentIndex = scanner.currentIndex
            return match
        }

        mutating func doScanString(_ string: String) -> Bool {
            scanner.currentIndex = currentIndex
            guard scanner.scanString(string) != nil else {
                return false
            }
            currentIndex = scanner.currentIndex
            return true
        }

        mutating func scanString(upTo token: String) throws -> String {
            scanner.currentIndex = currentIndex
            guard let match = scanner.scanUpToString(token) else {
                throw Error.invalid
            }

            currentIndex = scanner.currentIndex
            return match
        }
        
        mutating func scanString(upTo characters: Foundation.CharacterSet) throws -> String {
            let location = currentIndex
            guard let match = scanner.scanUpToCharacters(from: characters) else {
                scanner.currentIndex = location
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return match
        }
        
        mutating func scanCharacter(matchingAny characters: Foundation.CharacterSet) throws -> Character {
            let location = currentIndex
            guard let scalar = scanner.scan(first: characters) else {
                scanner.currentIndex = location
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return Character(scalar)
        }

        mutating func scanUInt8() throws -> UInt8 {
            scanner.currentIndex = currentIndex
            var longVal: UInt64 = 0
            guard
                scanner.scanUnsignedLongLong(&longVal),
                let val = UInt8(exactly: longVal) else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return val
        }
        
        mutating func scanFloat() throws -> Float {
            scanner.currentIndex = currentIndex
            guard let val = scanner.scanFloat() else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return val
        }
        
        mutating func scanDouble() throws -> Double {
            scanner.currentIndex = currentIndex
            guard let val = scanner.scanDouble() else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return val
        }

        mutating func scanUnit(_ unit: DOM.Unit) -> Bool {
            scanner.currentIndex = currentIndex
            guard scanner.scanString(unit.rawValue) != nil else {
                return false
            }
            currentIndex = scanner.currentIndex
            return true
        }

        mutating func scanUnit() -> DOM.Unit? {
            if scanUnit(.pixel) {
                return .pixel
            } else if scanUnit(.inch) {
                return .inch
            } else if scanUnit(.centimeter) {
                return .centimeter
            } else if scanUnit(.millimeter) {
                return .millimeter
            } else if scanUnit(.point) {
                return .point
            } else if scanUnit(.pica) {
                return .pica
            } else {
                return nil
            }
        }

        mutating func scanLength() throws -> DOM.Length {
            scanner.currentIndex = currentIndex
            guard
                let int64 = scanner.scanInt64(),
                let val = DOM.Length(exactly: int64),
                val >= 0 else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return val
        }
        
        mutating func scanBool() throws -> Bool {
            return try self.scanCase(from: Boolean.self).boolValue
        }
        
        mutating func scanCoordinate() throws -> DOM.Coordinate {
            let double = try scanDouble()
            let unit = scanUnit() ?? .pixel
            return DOM.Coordinate(double.apply(unit: unit))
        }
        
        mutating func scanPercentageFloat() throws -> Float {
            scanner.currentIndex = currentIndex
            let val = try scanFloat()
            guard val >= 0.0, val <= 1.0 else {
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
            return val
        }
        
        mutating func scanPercentage() throws -> Float {
            let initialLocation = currentIndex
            scanner.currentIndex = currentIndex
            
            let numeric = Foundation.CharacterSet(charactersIn: "+-0123456789.Ee")
            let numericString = try scanString(matchingAny: numeric)
            
            guard
                let val = Double(numericString),
                val >= 0, val <= 100,
                (scanner.scanString("%") != nil) || val == 0 else {
                currentIndex = initialLocation
                throw Error.invalid
            }
            currentIndex = scanner.currentIndex
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
        guard let match = Boolean.allCases.first(where: { self.scanString($0.rawValue) != nil }) else {
            throw Error.invalid
        }
        
        return match.boolValue
    }
    
    func scan(first set: Foundation.CharacterSet) -> UnicodeScalar? {
        let start = currentIndex
        guard let scalar = scanCharacters(from: set)?.unicodeScalars.first else {
            currentIndex = start
            return nil
        }

        currentIndex = start
        _ = scanCharacter()
        return scalar
    }
    
    func scanCoordinate() throws -> DOM.Coordinate {
        guard let val = scanDouble() else { throw XMLParser.Error.invalid }
        return DOM.Coordinate(val)
    }

    var currentOffet: Int {
        string.distance(from: string.startIndex, to: currentIndex)
    }
}
