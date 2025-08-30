//
//  ScannerTests.swift
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

public import Foundation
import Testing
@testable import SwiftDrawDOM

@Suite("Scanner Tests")
struct ScannerTests {

    @Test
    func isEOF() throws {
        var scanner = XMLParser.Scanner(text: "Hi")
        #expect(scanner.isEOF == false)
        try scanner.scanString("Hi")
        #expect(scanner.isEOF == true)
    }

    @Test
    func scanCharsetHex() throws {
        var scanner = XMLParser.Scanner(text: "  \t   8badf00d  \t  \t  007")
        #expect(try scanner.scanString(matchingAny: .hexadecimal) == "8badf00d")
        #expect(try scanner.scanString(matchingAny: .hexadecimal) == "007")
        #expect(throws: (any Error).self) { _ = try scanner.scanString(matchingAny: .hexadecimal) }
    }

    @Test
    func scanCharsetEmoji() throws {
        var scanner =  XMLParser.Scanner(text: "  \t   8badf00d  \t🐶  \t🌞🇦🇺  007")
        let emoji: Foundation.CharacterSet = "🤠🌞💎🐶\u{1f1e6}\u{1f1fa}"

        #expect(throws: (any Error).self) { _ = try scanner.scanString(matchingAny: emoji) }
        #expect(try scanner.scanString(matchingAny: .hexadecimal) == "8badf00d")
        #expect(throws: (any Error).self) { _ = try scanner.scanString(matchingAny: .hexadecimal) }
        #expect(try scanner.scanString(matchingAny: emoji) == "🐶")
        #expect(throws: (any Error).self) { _ = try scanner.scanString(matchingAny: .hexadecimal) }
        #expect(try scanner.scanString(matchingAny: emoji) == "🌞🇦🇺")
        #expect(throws: (any Error).self) { _ = try scanner.scanString(matchingAny: emoji) }
        #expect(try scanner.scanString(matchingAny: .hexadecimal) == "007")
    }

    @Test
    func scanString() throws {
        var scanner =  XMLParser.Scanner(text: "  \t The quick brown fox")

        #expect(throws: (any Error).self) { _ = try scanner.scanString("fox") }
        #expect(throws: Never.self) { try scanner.scanString("The") }
        #expect(throws: (any Error).self) { _ = try scanner.scanString("quick fox") }

        #expect(throws: Never.self) { try scanner.scanString("quick brown") }
        #expect(throws: Never.self) { try scanner.scanString("fox") }
        #expect(throws: (any Error).self) { _ = try scanner.scanString("fox") }
    }

    @Test
    func scanCase() throws {
        var scanner = XMLParser.Scanner(text: "NOT OK")
        #expect(try scanner.scanCase(from: Token.self) == .nok)
        #expect(try scanner.scanCase(from: Token.self) == .ok)
        #expect(throws: (any Error).self) { _ = try scanner.scanCase(from: Token.self) }
    }

    @Test
    func scanCharacter() throws {
        var scanner = XMLParser.Scanner(text: "  \t The fox 8badf00d ")

        #expect(throws: (any Error).self) { _ = try scanner.scanCharacter(matchingAny: "qfxh") }
        #expect(try scanner.scanCharacter(matchingAny: "fxT") == "T")
        #expect(throws: (any Error).self) { _ = try scanner.scanCharacter(matchingAny: "fxT") }
        #expect(try scanner.scanCharacter(matchingAny: "qfxh") == "h")
        #expect(throws: Never.self) { try scanner.scanString("e fox") }

        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "8")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "b")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "a")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "d")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "f")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "0")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "0")
        #expect(try scanner.scanCharacter(matchingAny: .hexadecimal) == "d")
    }

    @Test
    func scan_UInt8() {
        #expect(scanUInt8("0") == 0)
        #expect(scanUInt8("124") == 124)
        #expect(scanUInt8(" 045") == 45)
        #if canImport(Darwin)
        #expect(scanUInt8("-29") == nil)
        #endif
        #expect(scanUInt8("ab24") == nil)
    }

    @Test
    func scan_Float() {
        #expect(scanFloat("0") == 0)
        #expect(scanFloat("124") == 124)
        #expect(scanFloat(" 045") == 45)
        #expect(scanFloat("-29") == -29.0)
        #expect(scanFloat("ab24") == nil)
    }

    @Test
    func scan_Double() {
        #expect(scanDouble("0") == 0)
        #expect(scanDouble("124") == 124)
        #expect(scanDouble(" 045") == 45)
        #expect(scanDouble("-29") == -29)
        #expect(scanDouble("ab24") == nil)
    }

    @Test
    func scan_Length() {
        #expect(scanLength("0") == 0)
        #expect(scanLength("124") == 124)
        #expect(scanLength(" 045") == 45)
        #expect(scanLength("-29") == nil)
        #expect(scanLength("ab24") == nil)
    }

    @Test
    func scan_Bool() throws {
        #expect(scanBool("0") == false)
        #expect(scanBool("1") == true)
        #expect(scanBool("true") == true)
        #expect(scanBool("false") == false)
        #expect(scanBool("false") == false)

        var scanner = XMLParser.Scanner(text: "-29")
        #expect(throws: (any Error).self) { _ = try scanner.scanBool() }
        #expect(scanner.currentIndex == "".startIndex)
    }

    @Test
    func scan_PercentageFloat() {
        #expect(scanPercentageFloat("0") == 0)
        #expect(scanPercentageFloat("0.5") == 0.5)
        #expect(scanPercentageFloat("0.75") == 0.75)
        #expect(scanPercentageFloat("1.0") == 1.0)
        #expect(scanPercentageFloat("-0.5") == nil)
        #expect(scanPercentageFloat("1.5") == nil)
        #expect(scanPercentageFloat("as") == nil)
        #expect(scanPercentageFloat("29") == nil)
        #expect(scanPercentageFloat("24") == nil)
    }

    @Test
    func scan_Percentage() {
        #expect(scanPercentage("0") == 0)
        #expect(scanPercentage("0%") == 0)
        #expect(scanPercentage("100%") == 1.0)
        #expect(scanPercentage("100 %") == 1.0)
        #expect(scanPercentage("45.5 %") == 0.455)
        #expect(scanPercentage("0.5 %") == 0.005)
        #expect(scanPercentage("as") == nil)
        #expect(scanPercentage("29") == nil)
        #expect(scanPercentage("24") == nil)
    }

    @Test
    func scanCoordinate() throws {
        var scanner = XMLParser.Scanner(text: "10.05,12.04-49.05,30.02-10")

        #expect(try scanner.scanCoordinate() == 10.05)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 12.04)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == -49.05)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 30.02)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == -10)
    }

    @Test
    func scanCoordinate_Units() throws {
        var scanner = XMLParser.Scanner(text: "1, 2px, 1cm, 2mm, 1pt, 5pc")

        #expect(try scanner.scanCoordinate() == 1)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 2)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 37.795)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 2 * 3.7795)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 1 * 1.3333)
        _ = try? scanner.scanString(",")
        #expect(try scanner.scanCoordinate() == 5 * 16)
    }
}

private func scanUInt8(_ text: String) -> UInt8? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanUInt8()
}

private func scanFloat(_ text: String) -> Float? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanFloat()
}

private func scanDouble(_ text: String) -> Double? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanDouble()
}

private func scanLength(_ text: String) -> DOM.Length? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanLength()
}

private func scanBool(_ text: String) -> Bool? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanBool()
}

private func scanPercentage(_ text: String) -> Float? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanPercentage()
}

private func scanPercentageFloat(_ text: String) -> Float? {
    var scanner = XMLParser.Scanner(text: text)
    return try? scanner.scanPercentageFloat()
}

extension CharacterSet: @retroactive ExpressibleByExtendedGraphemeClusterLiteral {}
extension CharacterSet: @retroactive ExpressibleByUnicodeScalarLiteral {}
extension CharacterSet: @retroactive ExpressibleByStringLiteral {

    static let hexadecimal: Foundation.CharacterSet = "0123456789ABCDEFabcdef"

    public init(stringLiteral value: String) {
        self.init(charactersIn: value)
    }

}

enum Token: String, CaseIterable {
    case ok = "OK"
    case nok = "NOT"
}
