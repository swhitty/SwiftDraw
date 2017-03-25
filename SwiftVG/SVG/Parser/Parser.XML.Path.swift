//
//  Parser.XML.Path2.swift
//  SwiftVG
//
//  Created by Simon Whitty on 8/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XMLParser {
    
    typealias PathScanner = Foundation.Scanner
    
    typealias Segment = DOM.Path.Segment
    typealias Command = DOM.Path.Command
    typealias CoordinateSpace = DOM.Path.Segment.CoordinateSpace
    
    func parsePath(_ att: AttributeParser) throws -> DOM.Path {
        let path = DOM.Path(x: 0, y: 0)
        path.segments = try parsePathSegments(try att.parseString("d"))
        return path
    }
    
    func parsePathSegments(_ data: String) throws -> [Segment] {
        
        var segments = Array<Segment>()
        
        var scanner = PathScanner(text: data)
        
        scanner.charactersToBeSkipped = Foundation.CharacterSet.whitespacesAndNewlines
        
        var lastCommand: Command?
        
        repeat {
            if let cmd = parseCommand(&scanner) {
                lastCommand = cmd
            }
            guard let command = lastCommand else { throw Error.invalid }
            segments.append(try parsePathSegment(for: command, with: &scanner))
        } while !scanner.isEOF
        
        return segments
    }

    func parsePathSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        switch command {
        case .move, .moveRelative:
            return try parseMoveSegment(for: command, with: &scanner)
        case .line, .lineRelative:
            return try parseLineSegment(for: command, with: &scanner)
        case .horizontal, .horizontalRelative:
            return try parseHorizontalSegment(for: command, with: &scanner)
        case .vertical, .verticalRelative:
            return try parseVerticalSegment(for: command, with: &scanner)
        case .cubic, .cubicRelative:
            return try parseCubicSegment(for: command, with: &scanner)
        case .cubicSmooth, .cubicSmoothRelative:
            return try parseCubicSmoothSegment(for: command, with: &scanner)
        case .quadratic, .quadraticRelative:
            return try parseQuadraticSegment(for: command, with: &scanner)
        case .quadraticSmooth, .quadraticSmoothRelative:
            return try parseQuadraticSmoothSegment(for: command, with: &scanner)
        case .arc, .arcRelative:
            return try parseArcSegment(for: command, with: &scanner)
        case .close, .closeAlias:
            return .close
        }
    }

    func parseCommand(_ scanner: inout PathScanner) -> Command? {
        guard let char = scanner.scan(first: CharSet.commandSet),
              let command = Command(rawValue: char) else {
            return nil
        }
        return command
    }
    
    func parseMoveSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .move(x: x, y: y, space: command.coordinateSpace)
    }
    
    func parseLineSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
          _ = scanner.scan(first: CharSet.delimeter)
        
        return .line(x: x, y: y, space: command.coordinateSpace)
    }
    
    func parseHorizontalSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .horizontal(x: x, space: command.coordinateSpace)
    }
    
    func parseVerticalSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .vertical(y: y, space: command.coordinateSpace)
    }
    
    func parseCubicSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let x1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let x2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .cubic(x: x, y: y, x1: x1, y1: y1, x2: x2, y2: y2, space: command.coordinateSpace)
    }
    
    func parseCubicSmoothSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let x2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y2 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .cubicSmooth(x: x, y: y, x2: x2, y2: y2, space: command.coordinateSpace)
    }
    
    func parseQuadraticSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let x1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y1 = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .quadratic(x: x, y: y, x1: x1, y1: y1, space: command.coordinateSpace)
    }
    
    func parseQuadraticSmoothSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        
        return .quadraticSmooth(x: x, y: y, space: command.coordinateSpace)
    }

    func parseArcSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
        let rx = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let ry = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let rotate = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let large = try scanner.scanBool()
        _ = scanner.scan(first: CharSet.delimeter)
        let sweep = try scanner.scanBool()
        _ = scanner.scan(first: CharSet.delimeter)
        let x = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
        let y = try scanner.scanCoordinate()
        _ = scanner.scan(first: CharSet.delimeter)
 
        return .arc(rx: rx, ry: ry, rotate: rotate,
                    large: large, sweep: sweep,
                    x: x, y: y, space: command.coordinateSpace)
    }
}
