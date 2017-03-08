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
        
        if let move = try parseMoveSegment(&scanner) {
            return move
        } else if let line = try parseLineSegment(&scanner) {
            return line
        } else if let horizontal = try parseHorizontalSegment(&scanner) {
            return horizontal
        } else if let vertical = try parseVerticalSegment(&scanner) {
            return vertical
        } else if let cubic = try parseCubicSegment(&scanner) {
            return cubic
        } else if let cubicSmooth = try parseCubicSmoothSegment(&scanner) {
            return cubicSmooth
        } else if let quad = try parseQuadraticSegment(&scanner) {
            return quad
        } else if let quadSmooth = try parseQuadraticSmoothSegment(&scanner) {
            return quadSmooth
        } else if let arc = try parseArcSegment(&scanner) {
            return arc
        } else if let close = try parseCloseSegment(&scanner) {
            return close
        }
        
        throw Error.invalid
    }
    
    func parseMoveSegment(_ scanner: inout Scanner) throws -> Segment? {
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
    
    func parseLineSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
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
    
    func parseHorizontalSegment(_ scanner: inout Scanner) throws -> Segment? {
        guard let command = scanner.scan(first: "hH") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "H" ? .absolute : .relative
        
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .horizontal(x: x, space: space)
    }
    
    func parseVerticalSegment(_ scanner: inout Scanner) throws -> Segment? {
        guard let command = scanner.scan(first: "vV") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "V" ? .absolute : .relative
        
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .vertical(y: y, space: space)
    }
    
    func parseCubicSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let command = scanner.scan(first: "Cc") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "C" ? .absolute : .relative

        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let x1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let x2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .cubic(x: x, y: y, x1: x1, y1: y1, x2: x2, y2: y2, space: space)
    }
    
    func parseCubicSmoothSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let command = scanner.scan(first: "Ss") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "S" ? .absolute : .relative
        
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let x2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .cubicSmooth(x: x, y: y, x2: x2, y2: y2, space: space)
    }
    
    func parseQuadraticSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let command = scanner.scan(first: "Qq") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "Q" ? .absolute : .relative
        
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let x1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .quadratic(x: x, y: y, x1: x1, y1: y1, space: space)
    }
    
    func parseQuadraticSmoothSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let command = scanner.scan(first: "Tt") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "T" ? .absolute : .relative
        
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        
        return .quadraticSmooth(x: x, y: y, space: space)
    }
    
    func parseArcSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let command = scanner.scan(first: "Aa") else {
            return nil
        }
        
        let space: CoordinateSpace = command == "A" ? .absolute : .relative
        
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let rx = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let ry = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let rotate = try scanner.scanCoordinate()
        _ = scanner.scan(first: ";,")
        let large = try scanner.scanBool()
        _ = scanner.scan(first: ";,")
        let sweep = try scanner.scanBool()
        _ = scanner.scan(first: ";,")
 
        return .arc(x: x, y: y,
                    rx: rx, ry: ry,
                    rotate: rotate, large: large,
                    sweep: sweep, space: space)
    }
    
    func parseCloseSegment(_ scanner: inout Scanner) throws -> DOM.Path2.Segment? {
        guard let _ = scanner.scan(first: "Zz") else {
            return nil
        }
        return .close
    }


}
