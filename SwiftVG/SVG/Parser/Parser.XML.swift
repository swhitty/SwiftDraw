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
    
    func parseFillRule(_ text: String) throws -> DOM.FillRule {
        guard let rule = DOM.FillRule(rawValue: trim(text)) else {
            throw Error.invalid
        }
        return rule
    }
    
    func parseFillRule(_ text: String?) throws -> DOM.FillRule? {
        guard let text = text else { return nil }
        return try parseFillRule(text)
    }
    
    func parseDisplayMode(_ text: String) throws -> DOM.DisplayMode {
        guard let mode = DOM.DisplayMode(rawValue: trim(text)) else {
            throw Error.invalid
        }
        return mode
    }
    
    func parseDisplayMode(_ text: String?) throws -> DOM.DisplayMode? {
        guard let text = text else { return nil }
        return try parseDisplayMode(text)
    }
    
    func parseLineCap(_ text: String) throws -> DOM.LineCap {
        guard let cap = DOM.LineCap(rawValue: trim(text)) else {
            throw Error.invalid
        }
        return cap
    }
    
    func parseLineCap(_ text: String?) throws -> DOM.LineCap? {
        guard let text = text else { return nil }
        return try parseLineCap(text)
    }
    
    func parseLineJoin(_ text: String) throws -> DOM.LineJoin {
        guard let join = DOM.LineJoin(rawValue: trim(text)) else {
            throw Error.invalid
        }
        return join
    }
    
    func parseLineJoin(_ text: String?) throws -> DOM.LineJoin? {
        guard let text = text else { return nil }
        return try parseLineJoin(text)
    }
    
    func parseDashArray(_ text: String?) throws -> [DOM.Float]? {
        guard let text = text else { return nil }

        var array = Array<DOM.Float>()
        var scanner = Scanner(text: text)
        while scanner.isEOF == false {
            array.append(try scanner.scanFloat())
            _ = scanner.scan(",")
        }

        return array
    }
    
    func trim(_ t: String) -> String {
        return t.trimmingCharacters(in: .whitespaces)
    }
    
    // parse any URL 
    // #someId
    // www.google.com
    // data:image/png;base64,00aa
    func parseUrl(_ text: String) throws -> URL {
        guard let url = URL(string: text) else {
            throw Error.invalid
        }
        return url
    }
    
    func parseUrl(_ text: String?) throws -> URL? {
        guard let text = text else { return nil }
        return try parseUrl(text)
    }
    
    // parse url wrapped in url()
    // =url(#someId)
    func parseUrlSelector(_ text: String) throws -> URL {
        var scanner = Scanner(text: text)
        guard scanner.scan("url(") != nil,
              let urlText = scanner.scan(upTo: ")"),
              urlText.characters.count > 0 else {
                throw Error.invalid
        }
        _ = scanner.scan(")")
        
        guard scanner.isEOF else {
            throw Error.invalid
        }
        
        return try parseUrl(urlText.trimmingCharacters(in: .whitespaces))
    }
    
    func parseUrlSelector(_ text: String?) throws -> URL? {
        guard let text = text else { return nil }
        return try parseUrlSelector(text)
    }
}
