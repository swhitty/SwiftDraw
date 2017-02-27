//
//  Parser.XML.Path.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parsePath(_ e: XML.Element) throws -> DOM.Path {
        let att = try parseStyleAttributes(e)
        guard e.name == "path",
            let d = att["d"] else {
            throw Error.invalid
        }
        
        let path = DOM.Path(x: 0, y: 0)
        path.segments = try parsePathSegments(data: d)
        
        if let fillRule = att["fill-rule"] {
            path.fillRule = try parseFillRule(data: fillRule)
        }
        
        return path
    }
    
    func parsePathSegments(data: String) throws -> [DOM.Path.Segment] {
        
        var segments = Array<DOM.Path.Segment>()
        
        var scanner = PathScanner(data: data)
        
        while let s = try? scanner.scanSegment() {
            segments.append(s)
        }
        
        return segments
    }
    
    struct PathScanner {
        var scanner: Scanner
        
        init(data: String) {
            scanner = Scanner(text: data)
        }
        
        enum Error: Swift.Error {
            case invalid
        }
        
        let commands: CharacterSet = "MmLlHhVvCcSsQqTtAaZz"
        let delimiter: CharacterSet = ";,"
        
        mutating func scanCommand() throws -> Formatter.XML.Path.Command {
            let start = scanner.index
            
            guard let c = scanner.scan(first: commands),
                let cmd = Formatter.XML.Path.Command(rawValue: c) else {
                scanner.index = start
                throw Error.invalid
            }
            
            return cmd
        }
        
        mutating func scanSegment() throws -> DOM.Path.Segment {
            let start = scanner.index
            let cmd = try scanCommand()
            
            do {
                return try scanSegment(for: cmd)
            } catch {
                scanner.index = start
                throw Error.invalid
            }
        }
        
        mutating func scanSegment(for cmd: Formatter.XML.Path.Command) throws -> DOM.Path.Segment {
            
            let space = XMLParser.coordinateSpace(for: cmd)
            
            switch cmd {
            case .move,
                 .moveRelative: return .move(try scanMove(), space)
            case .line,
                 .lineRelative: return .line(try scanLine(), space)
            case .horizontal,
                 .horizontalRelative: return .horizontal(try scanHorizontal(), space)
            case .vertical,
                 .verticalRelative: return .vertical(try scanVertical(), space)
            case .cubic,
                 .cubicRelative: return .cubic(try scanCubic(), space)
            case .cubicSmooth,
                 .cubicSmoothRelative: return .cubicSmooth(try scanCubicSmooth(), space)
            case .quadratic,
                 .quadraticRelative: return .quadratic(try scanQuadratic(), space)
            case .quadraticSmooth,
                 .quadraticSmoothRelative: return .quadraticSmooth(try scanQuadraticSmooth(), space)
            case .arc,
                 .arcRelative: return .arc(try scanArc(), space)
            case .close,
                 .closeAlias: return .close
            }
        }
        
        mutating func scanMove() throws -> DOM.Path.Move {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            
            return DOM.Path.Move(x, y)
        }
        
        mutating func scanLine() throws -> DOM.Path.Line {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            
            return DOM.Path.Line(x, y)
        }
        
        mutating func scanHorizontal() throws -> DOM.Path.Horizontal {
            let x = try scanner.scanCoordinate()
            return DOM.Path.Horizontal(x)
        }
        
        mutating func scanVertical() throws -> DOM.Path.Vertical {
            let y = try scanner.scanCoordinate()
            return DOM.Path.Vertical(y)
        }
        
        mutating func scanCubic() throws -> DOM.Path.Cubic {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let x1 = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y1 = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let x2 = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y2 = try scanner.scanCoordinate()
            
            return DOM.Path.Cubic(x, y, x1, y1, x2, y2)
        }
        
        mutating func scanCubicSmooth() throws -> DOM.Path.CubicSmooth {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let x2 = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y2 = try scanner.scanCoordinate()
            
            return DOM.Path.CubicSmooth(x, y, x2, y2)
        }
        
        mutating func scanQuadratic() throws -> DOM.Path.Quadratic {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let x1 = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y1 = try scanner.scanCoordinate()
            
            return DOM.Path.Quadratic(x, y, x1, y1)
        }
        
        mutating func scanQuadraticSmooth() throws -> DOM.Path.QuadraticSmooth {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            
            return DOM.Path.QuadraticSmooth(x, y)
        }
        
        mutating func scanArc() throws -> DOM.Path.Arc {
            let x = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let y = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let rx = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let ry = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let rotate = try scanner.scanCoordinate()
            _ = scanner.scan(first: delimiter)
            let large = try scanner.scanBool()
            _ = scanner.scan(first: delimiter)
            let sweep = try scanner.scanBool()
            
            return DOM.Path.Arc(x, y, rx, ry, rotate, large, sweep)
        }
    }
    
    static func coordinateSpace(for command: Formatter.XML.Path.Command) -> DOM.Path.Segment.CoordinateSpace {
        switch command {
        case .move,
             .line,
             .horizontal,
             .vertical,
             .cubic,
             .cubicSmooth,
             .quadratic,
             .quadraticSmooth,
             .arc,
             .close,
             .closeAlias: return .absolute
        case .moveRelative,
             .lineRelative,
             .horizontalRelative,
             .verticalRelative,
             .cubicRelative,
             .cubicSmoothRelative,
             .quadraticRelative,
             .quadraticSmoothRelative,
             .arcRelative: return .relative
        }
    }
    
}
