//
//  Parser.XML.Path.swift
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
    
    var scanner = PathScanner(string: data)
    
    scanner.charactersToBeSkipped = Foundation.CharacterSet.whitespacesAndNewlines
    
    var lastCommand: Command?
    
    repeat {
      guard let cmd = nextPathCommand(&scanner, lastCommand: lastCommand) else {
        throw Error.invalid
      }
      lastCommand = cmd
      segments.append(try parsePathSegment(for: cmd, with: &scanner))
    } while !scanner.isAtEnd
    
    return segments
  }

  func nextPathCommand(_ scanner: inout PathScanner, lastCommand: Command?) -> Command? {
    if let cmd = parseCommand(&scanner) {
      return cmd
    }

    switch lastCommand {
    case .some(.move):
      return .line
    case .some(.moveRelative):
      return .lineRelative
    default:
      return lastCommand
    }
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
    guard let char = scanner.scan(first: .commands),
      let command = Command(rawValue: char) else {
        return nil
    }
    return command
  }
  
  func parseMoveSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .move(x: x, y: y, space: command.coordinateSpace)
  }
  
  func parseLineSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .line(x: x, y: y, space: command.coordinateSpace)
  }
  
  func parseHorizontalSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .horizontal(x: x, space: command.coordinateSpace)
  }
  
  func parseVerticalSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .vertical(y: y, space: command.coordinateSpace)
  }
  
  func parseCubicSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x1 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y1 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let x2 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y2 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .cubic(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y, space: command.coordinateSpace)
  }
  
  func parseCubicSmoothSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x2 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y2 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .cubicSmooth(x2: x2, y2: y2, x: x, y: y, space: command.coordinateSpace)
  }
  
  func parseQuadraticSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x1 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y1 = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .quadratic(x1: x1, y1: y1, x: x, y: y, space: command.coordinateSpace)
  }
  
  func parseQuadraticSmoothSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .quadraticSmooth(x: x, y: y, space: command.coordinateSpace)
  }
  
  func parseArcSegment(for command: Command, with scanner: inout PathScanner) throws -> Segment {
    let rx = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let ry = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let rotate = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let large = try scanner.scanBool()
    _ = scanner.scan(first: .delimeter)
    let sweep = try scanner.scanBool()
    _ = scanner.scan(first: .delimeter)
    let x = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    let y = try scanner.scanCoordinate()
    _ = scanner.scan(first: .delimeter)
    
    return .arc(rx: rx, ry: ry, rotate: rotate,
                large: large, sweep: sweep,
                x: x, y: y, space: command.coordinateSpace)
  }
}

private extension CharacterSet {
  static let delimeter = CharacterSet(charactersIn: ",;")
  static let commands = CharacterSet(charactersIn: "MmLlHhVvCcSsQqTtAaZz")
}
