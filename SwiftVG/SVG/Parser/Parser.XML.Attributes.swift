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
    func parseFloat(_ key: String) throws -> DOM.Float
    func parsePercentage(_ key: String) throws -> DOM.Float
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate
    func parseLength(_ key: String) throws -> DOM.Length
    func parseBool(_ key: String) throws -> DOM.Bool
    func parseColor(_ key: String) throws -> DOM.Color
    func parseUrl(_ key: String) throws -> URL
    // e.g. url(#someId)
    func parseUrlSelector(_ key: String) throws -> URL
    
    func parsePoints(_ key: String) throws -> [DOM.Point]
    func parseDashArray(_ key: String) throws -> [DOM.Float]
    
    //any string backed enum
    func parseRaw<T: RawRepresentable>(_ key: String) throws -> T? where T.RawValue == String
}

extension AttributeParser {
    
    func parseOptional<T>(_ exp: @autoclosure () throws -> T) throws -> T? {
        do {
            return try exp()
        } catch XMLParser.Error.missingAttribute(name: _) {
            return nil
        }
    }
    
    func parseString(_ key: String) -> String? {
        return try? parseString(key)
    }
    
    func parseFloat(_ key: String) throws -> DOM.Float? {
        return try parseOptional(try parseFloat(key))
    }
    
    func parsePercentage(_ key: String) throws -> DOM.Float? {
        return try parseOptional(try parsePercentage(key))
    }
    
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate? {
        return try parseOptional(try parseCoordinate(key))
    }
    
    func parseLength(_ key: String) throws -> DOM.Length? {
        return try parseOptional(try parseLength(key))
    }
    
    func parseBool(_ key: String) throws -> DOM.Bool? {
        return try parseOptional(try parseBool(key))
    }
    
    func parseColor(_ key: String) throws -> DOM.Color? {
        return try parseOptional(try parseColor(key))
    }
    
    func parseUrl(_ key: String) throws -> URL? {
        return try parseOptional(try parseUrl(key))
    }
    
    func parseUrlSelector(_ key: String) throws -> URL? {
        return try parseOptional(try parseUrlSelector(key))
    }

    func parsePoints(_ key: String) throws -> [DOM.Point]? {
        return try parseOptional(try parsePoints(key))
    }

    func parseDashArray(_ key: String) throws -> [DOM.Float]? {
        return try parseOptional(try parseDashArray(key))
    }
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
    

    final class AttributesA: AttributeParserA {
        
        var parser: AttributeValueParserA
        var options: XMLParser.Options
        
        var element: [String: String]
        var style: [String: String]
        
        init(parser: AttributeValueParserA,
             options: XMLParser.Options = [],
             element: [String: String],
             style: [String: String]) {
            self.parser = parser
            self.options = options
            self.element = element
            self.style = style
        }
        
        subscript(name: String) -> String? {
            get {
                return style[name] ?? element[name]
            }
        }
        
        func parse<T>(_ key: String, _ exp: (String) throws -> T) throws -> T {
            do {
                return try parse(style[key], with: exp, for: key)
            } catch XMLParser.Error.missingAttribute(_) {
                return try parse(element[key], with: exp, for: key)
            } catch let error {
                guard options.contains(.skipInvalidAttributes) else { throw error }
                return try parse(element[key], with: exp, for: key)
            }
        }
        
        func parse<T>(_ value: String?, with expression: (String) throws -> T, for key: String) throws -> T {
            guard let value = style[key] else { throw XMLParser.Error.missingAttribute(name: key) }
            return try expression(value)
        }
    }
}


extension XMLParser {
    
    struct ValueParser: AttributeValueParserA {
        
        func parseFloat(_ value: String) throws -> DOM.Float {
            var scanner = Scanner(text: value)
            return try scanner.scanFloat()
        }
        
        func parseFloats(_ value: String) throws -> [DOM.Float] {
            var array = Array<DOM.Float>()
            var scanner = Scanner(text: value)
            
            while !scanner.isEOF {
                let vx = try? scanner.scanFloat()
                _ = scanner.scan(first: ",")
                guard let v = vx else { throw XMLParser.Error.invalid }
                array.append(v)
            }
            
            return array
        }
        
        
        func parsePercentage(_ value: String) throws -> DOM.Float {
            var scanner = Scanner(text: value)
            return try scanner.scanPercentage()
        }
        
        func parseCoordinate(_ value: String) throws -> DOM.Coordinate {
            var scanner = Scanner(text: value)
            return try scanner.scanCoordinate()
        }
        
        func parseLength(_ value: String) throws -> DOM.Length {
            var scanner = Scanner(text: value)
            return try scanner.scanLength()
        }
        
        func parseBool(_ value: String) throws -> DOM.Bool {
            var scanner = Scanner(text: value)
            return try scanner.scanBool()
        }
        
        func parseColor(_ value: String) throws -> DOM.Color {
            return try XMLParser().parseColor(data: value)
        }
        
        func parseUrl(_ value: String) throws -> DOM.URL {
            guard let url = URL(string: value) else { throw XMLParser.Error.invalid }
            return url
            
        }
        func parseUrlSelector(_ value: String) throws -> DOM.URL {
            var scanner = Scanner(text: value)
            guard scanner.scan("url(") != nil,
                let urlText = scanner.scan(upTo: ")") else { throw XMLParser.Error.invalid }
            
            _ = scanner.scan(")")
            
            let url = urlText.trimmingCharacters(in: .whitespaces)
            
            guard url.characters.count > 0,
                  scanner.isEOF else { throw XMLParser.Error.invalid }
            
            return try parseUrl(url)
        }
        
        func parsePoints(_ value: String) throws -> [DOM.Point] {
            var points = Array<DOM.Point>()
            var scanner = Scanner(text: value)
            
            while !scanner.isEOF {
                let px = try? scanner.scanCoordinate()
                _ = scanner.scan(first: ",;")
                let py = try? scanner.scanCoordinate()
                _ = scanner.scan(first: ",;")
                
                guard let x = px,
                      let y = py else { throw XMLParser.Error.invalid }
                
                points.append(DOM.Point(x, y))
            }
            
            return points
        }
        
        func parseRaw<T: RawRepresentable>(_ value: String) throws -> T where T.RawValue == String {
            guard let obj = T(rawValue: value.trimmingCharacters(in: .whitespaces)) else {
                throw XMLParser.Error.invalid
            }
            return obj
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
    
    func parseFloat(_ key: String) throws -> DOM.Float {
        let value = try getValue(key)
        var scanner = Scanner(text: value)
        guard let float = try? scanner.scanFloat() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return float
    }
    
    func parsePercentage(_ key: String) throws -> DOM.Float {
        let value = try getValue(key)
        var scanner = Scanner(text: value)
        guard let pc = try? scanner.scanPercentage() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return pc
    }
    
    func parseCoordinate(_ key: String) throws -> DOM.Coordinate {
        let value = try getValue(key)
        var scanner = Scanner(text: value)
        guard let coord = try? scanner.scanCoordinate() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return coord
    }
    
    func parseLength(_ key: String) throws -> DOM.Length {
        let value = try getValue(key)
        var scanner = Scanner(text: value)
        guard let length = try? scanner.scanLength() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return length
    }
    
    func parseBool(_ key: String) throws -> DOM.Bool {
        let value = try getValue(key)
        var scanner = Scanner(text: value)
        guard let bool = try? scanner.scanBool() else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return bool
    }
    
    func parseColor(_ key: String) throws -> DOM.Color {
        let value = try getValue(key)
        guard let color = try? XMLParser().parseColor(data: value) else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return color
    }
    
    func parsePoints(_ key: String) throws -> [DOM.Point] {
        let value = try getValue(key)
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
    
    // URL
    func doParseUrl(_ value: String, for key: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return url
    }

    func parseUrl(_ key: String) throws -> URL {
        let value = try getValue(key)
        return try doParseUrl(value, for: key)
    }
    
    func parseUrlSelector(_ key: String) throws -> URL {
        let value = try getValue(key)
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
    
    func parseDashArray(_ key: String) throws -> [DOM.Float] {
        let value = try getValue(key)
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

    func parseRaw<T: RawRepresentable>(_ key: String) throws -> T? where T.RawValue == String {
        guard let value = self[key] else { return nil }
        guard let obj = T(rawValue: value.trimmingCharacters(in: .whitespaces)) else {
            throw XMLParser.Error.invalidAttribute(name: key, value: value)
        }
        return obj
    }

}

