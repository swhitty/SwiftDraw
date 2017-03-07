//
//  Parser.XML.Path2.swift
//  SwiftVG
//
//  Created by Simon Whitty on 8/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    typealias Segment = DOM.Path2.Segment
    typealias CoordinateSpace = DOM.Path2.Segment.CoordinateSpace
    
    func parsePath2(_ att: AttributeParser) throws -> DOM.Path2 {
        let path = DOM.Path2(x: 0, y: 0)
        path.segments = try parsePathSegments(try att.parseString("d"))
        return path
    }
    
    func parsePathSegments(_ data: String) throws -> [Segment] {
        
        var segments = Array<Segment>()
        
        var scanner = Scanner(text: data)
        
        while !scanner.isEOF {
            segments.append(try parsePathSegment(&scanner))
        }
        
        return segments
    }
    
    func parsePathSegment(_ scanner: inout Scanner) throws -> Segment {
        
        if let move = try parsePathMove(&scanner) {
            return move
        }
        if let line = try parsePathLine(&scanner) {
            return line
        }
        
        throw Error.invalid
    }
    
    func parsePathMove(_ scanner: inout Scanner) throws -> Segment? {
        guard let command = scanner.scan(first: "mM") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "M" ? .absolute : .relative
        
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .move(x: x, y: y, space: space)
    }
    
    func parsePathLine(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let command = scanner.scan(first: "lL") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "L" ? .absolute : .relative
        
        let x1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y1 = try scanner.scanCoordinate()
          _ = scanner.scan(first: ";,")
        let x2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .line(x1: x1, y1: y1, x2: x2, y2: y2, space: space)
    }
}
