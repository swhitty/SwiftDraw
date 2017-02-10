//
//  Parser.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

struct XMLParser {
    
    enum Error: Swift.Error {
        case invalid
    }
    
    func parseCoordinate(_ text: String) throws -> DOM.Coordinate {
        var scanner = Scanner(text: text)
        return try scanner.scanCoordinate()
    }

    func parseCoordinate(_ text: String?) throws -> DOM.Coordinate? {
        guard let text = text else { return nil }
        return try parseCoordinate(text)
    }
    
    func parseLength(_ text: String) throws -> DOM.Length {
        var scanner = Scanner(text: text)
        return try scanner.scanLength()
    }
    
    func parseLength(_ text: String?) throws -> DOM.Length? {
        guard let text = text else { return nil }
        return try parseLength(text)
    }
    
    func parsePercentage(_ text: String) throws -> DOM.Float {
        var scanner = Scanner(text: text)
        return try scanner.scanPercentage()
    }
    
    func parsePercentage(_ text: String?) throws -> DOM.Float? {
        guard let text = text else { return nil }
        return try parsePercentage(text)
    }
    
    func parseFloat(_ text: String) throws -> DOM.Float {
        var scanner = Scanner(text: text)
        return try scanner.scanFloat()
    }
    
    func parseFloat(_ text: String?) throws -> DOM.Float? {
        guard let text = text else { return nil }
        return try parseFloat(text)
    }
    
    func parseFillRule(data: String) throws -> DOM.FillRule {
        let v = data.trimmingCharacters(in: .whitespaces)
        guard let rule = DOM.FillRule(rawValue: v) else {
            throw Error.invalid
        }
        return rule
    }
}
