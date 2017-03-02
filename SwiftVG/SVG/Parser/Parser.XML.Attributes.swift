//
//  Parser.XML.Attributes.swift
//  SwiftVG
//
//  Created by Simon Whitty on 2/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation


protocol AttributeParser {
    func parseString(_ key: String) throws -> String
    func parseString(_ key: String) -> String?
    
    func parseFloat(_ key: String) throws -> DOM.Float
    func parseFloat(_ key: String) throws -> DOM.Float?
    
    func parsePercentage(_ key: String) throws -> DOM.Float
    func parsePercentage(_ key: String) throws -> DOM.Float?
    
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate?
    
    func parseLength(_ key: String) throws -> DOM.Length
    func parseLength(_ key: String) throws -> DOM.Length?
    
    func parseBool(_ key: String) throws -> DOM.Bool
    func parseBool(_ key: String) throws -> DOM.Bool?
    
    func parseColor(_ key: String) throws -> DOM.Color
    func parseColor(_ key: String) throws -> DOM.Color?
    
    func parsePoints(_ key: String) throws -> [DOM.Point]
    func parsePoints(_ key: String) throws -> [DOM.Point]?
    
    // parse url wrapped in url()
    // =url(#someId)
    func parseUrl(_ key: String) throws -> URL
    func parseUrl(_ key: String) throws -> URL?
    func parseUrlSelector(_ key: String) throws -> URL?
    func parseFillRule(_ key: String) throws -> DOM.FillRule?
    func parseDisplayMode(_ key: String) throws -> DOM.DisplayMode?
    func parseLineCap(_ key: String) throws -> DOM.LineCap?
    func parseLineJoin(_ key: String) throws -> DOM.LineJoin?
    func parseDashArray(_ key: String) throws -> [DOM.Float]?
}


extension XMLParser {
    // Storage for merging XMLElement attibutes and style properties;
    // style properties have precedence over element attibutes
    // <line stroke="none" fill="red" style="stroke: 2" />
    // attributes["stoke"] == "2"
    // attributes["fill"] == "red"
    final class Attributes {
        var element: [String: String]
        var style: [String: String]
        
        init(element: [String: String], style: [String: String]) {
            self.element = element
            self.style = style
        }
        
        subscript(name: String) -> String? {
            get {
                return style[name] ?? element[name]
            }
        }
        
        var properties: [String: String] {
            var props = element
            for (name, value) in style {
                props[name] = value
            }
            return props
        }
    }
}


extension XMLParser.Attributes: AttributeParser {

    func getValue(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw XMLParser.Error.missingAttribute(name: key)
        }
        return value
    }
    
    func parseString(_ key: String) throws -> String {
        return try getValue(key)
    }
    
    func parseString(_ key: String) -> String? {
        return self[key]
    }
    
    // Float
    func doParseFloat(_ value: String, for key: String) throws -> DOM.Float {
        var scanner = Scanner(text: value)
        guard let float = try? scanner.scanFloat() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return float
    }
    
    func parseFloat(_ key: String) throws -> DOM.Float {
        let value = try getValue(key)
        return try doParseFloat(value, for: key)
    }
    
    func parseFloat(_ key: String) throws -> DOM.Float? {
        guard let value = self[key] else { return nil }
        return try doParseFloat(value, for: key)
    }
    
    // Percentage
    func doParsePercentage(_ value: String, for key: String) throws -> DOM.Float {
        var scanner = Scanner(text: value)
        guard let pc = try? scanner.scanPercentage() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return pc
    }
    
    func parsePercentage(_ key: String) throws -> DOM.Float {
        let value = try getValue(key)
        return try doParsePercentage(value, for: key)
    }
    
    func parsePercentage(_ key: String) throws -> DOM.Float? {
        guard let value = self[key] else { return nil }
        return try doParsePercentage(value, for: key)
    }
    
    // Coordinate
    func doParseCoordinate(_ value: String, for key: String) throws -> DOM.Coordinate {
        var scanner = Scanner(text: value)
        guard let coord = try? scanner.scanCoordinate() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return coord
    }
    
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate {
        let value = try getValue(key)
        return try doParseCoordinate(value, for: key)
    }
    
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate? {
        guard let value = self[key] else { return nil }
        return try doParseCoordinate(value, for: key)
    }
    
    // Length
    func doParseLength(_ value: String, for key: String) throws -> DOM.Length {
        var scanner = Scanner(text: value)
        guard let length = try? scanner.scanLength() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return length
    }
    
    func parseLength(_ key: String) throws -> DOM.Length {
        let value = try getValue(key)
        return try doParseLength(value, for: key)
    }
    
    func parseLength(_ key: String) throws -> DOM.Length? {
        guard let value = self[key] else { return nil }
        return try doParseLength(value, for: key)
    }
    
    // Bool
    func doParseBool(_ value: String, for key: String) throws -> DOM.Bool {
        var scanner = Scanner(text: value)
        guard let bool = try? scanner.scanBool() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return bool
    }
    
    func parseBool(_ key: String) throws -> DOM.Bool {
        let value = try getValue(key)
        return try doParseBool(value, for: key)
    }
    
    func parseBool(_ key: String) throws -> DOM.Bool? {
        guard let value = self[key] else { return nil }
        return try doParseBool(value, for: key)
    }
    
    //Color
    func doParseColor(_ value: String, for key: String) throws -> DOM.Color {
        guard let color = try? XMLParser().parseColor(data: value) else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return color
    }
    
    func parseColor(_ key: String) throws -> DOM.Color {
        let value = try getValue(key)
        return try doParseColor(value, for: key)
    }
    
    func parseColor(_ key: String) throws -> DOM.Color? {
        guard let value = self[key] else { return nil }
        return try doParseColor(value, for: key)
    }
    
    // Points
    func doParsePoints(_ value: String, for key: String) throws -> [DOM.Point] {
        var points = Array<DOM.Point>()
        var scanner = Scanner(text: value)
        
        while !scanner.isEOF {

            let px = try? scanner.scanCoordinate()
            _ = scanner.scan(first: ",;")
            let py = try? scanner.scanCoordinate()
            _ = scanner.scan(first: ",;")
            
            guard let x = px,
                  let y = py else {
                throw XMLParser.Error.invalidAttribute(name: key, value: value)
            }
            points.append(DOM.Point(x, y))
        }

        return points
    }
    
    func parsePoints(_ key: String) throws -> [DOM.Point] {
        let value = try getValue(key)
        return try doParsePoints(value, for: key)
    }
    
    func parsePoints(_ key: String) throws -> [DOM.Point]? {
        guard let value = self[key] else { return nil }
        return try doParsePoints(value, for: key)
    }
    
    // URL
    func doParseUrl(_ value: String, for key: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return url
    }
    
    func doParseUrlSelector(_ value: String, for key: String) throws -> URL {
        var scanner = Scanner(text: value)
        guard scanner.scan("url(") != nil,
            let urlText = scanner.scan(upTo: ")") else {
                throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        _ = scanner.scan(")")
        
        let url = urlText.trimmingCharacters(in: .whitespaces)
        
        guard url.characters.count > 0,
            scanner.isEOF else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
 
        return try doParseUrl(url, for: key)
    }
    
    func parseUrl(_ key: String) throws -> URL {
        let value = try getValue(key)
        return try doParseUrl(value, for: key)
    }
    
    func parseUrl(_ key: String) throws -> URL? {
        guard let value = self[key] else { return nil }
        return try doParseUrl(value, for: key)
    }
    
    func parseUrlSelector(_ key: String) throws -> URL {
        let value = try getValue(key)
        return try doParseUrlSelector(value, for: key)
    }
    
    func parseUrlSelector(_ key: String) throws -> URL? {
        guard let value = self[key] else { return nil }
        return try doParseUrlSelector(value, for: key)
    }
    
    func parseDashArray(_ key: String) throws -> [DOM.Float]? {
        guard let value = self[key] else { return nil }
            
        var array = Array<DOM.Float>()
        var scanner = Scanner(text: value)

        while !scanner.isEOF {
            let vx = try? scanner.scanFloat()
            _ = scanner.scan(first: ",")
            guard let v = vx else {
                throw XMLParser.Error.invalidAttribute(name: key, value: value)
            }
            array.append(v)
        }
        
        return array
    }

    
    //RawRepresentable
    func doParseRaw<T: RawRepresentable>(_ value: String, for key: String) throws -> T where T.RawValue == String {
        guard let obj = T(rawValue: value.trimmingCharacters(in: .whitespaces)) else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return obj
    }
    
    func parseFillRule(_ key: String) throws -> DOM.FillRule? {
        guard let value = self[key] else { return nil }
        return try doParseRaw(value, for: key) as DOM.FillRule
    }
    
    func parseDisplayMode(_ key: String) throws -> DOM.DisplayMode? {
        guard let value = self[key] else { return nil }
        return try doParseRaw(value, for: key) as DOM.DisplayMode
    }
    
    func parseLineCap(_ key: String) throws -> DOM.LineCap? {
        guard let value = self[key] else { return nil }
        return try doParseRaw(value, for: key) as DOM.LineCap
    }
    
    func parseLineJoin(_ key: String) throws -> DOM.LineJoin? {
        guard let value = self[key] else { return nil }
        return try doParseRaw(value, for: key) as DOM.LineJoin
    }
}

