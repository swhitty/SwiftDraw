//
//  Formatter.XML.Path.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2016 Simon Whitty
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

extension XMLFormatter {
    
    struct Path {
        
        var coordinateFormatter = XMLFormatter.CoordinateFormatter() { didSet {
            segmentFormatter.coordinateFormatter = coordinateFormatter
        } }
        
        var segmentFormatter = SegmentFormatter()
        
        func format(_ path: DOM.Path) -> XML.Element {
            var att = XMLFormatter.attributes(for: path)
            att["d"] = format(path.segments)
            let element = XML.Element(name: "path", attributes: att)
            return element
        }
        
        func format(_ segments: [DOM.Path.Segment]) -> String {
            let formatter = segmentFormatter
            return segments.map { formatter.format($0) }.joined(separator: " ")
        }
    }
}

extension XMLFormatter.Path {
    
    enum Command: Character {
        case move = "M"
        case moveRelative = "m"
        case line = "L"
        case lineRelative = "l"
        case horizontal = "H"
        case horizontalRelative = "h"
        case vertical = "V"
        case verticalRelative = "v"
        case cubic = "C"
        case cubicRelative = "c"
        case cubicSmooth = "S"
        case cubicSmoothRelative = "s"
        case quadratic = "Q"
        case quadraticRelative = "q"
        case quadraticSmooth = "T"
        case quadraticSmoothRelative = "t"
        case arc = "A"
        case arcRelative = "a"
        case close = "Z"
        case closeAlias = "z"
    }
    
    struct SegmentFormatter {
        
        var delimeter = Delimeter.space
        var coordinateFormatter = XMLFormatter.CoordinateFormatter()
        
        enum Delimeter: String {
            case space = " "
            case none = ""
        }
        
        func format(_ segment: DOM.Path.Segment) -> String {
            let cmd = format(command: segment)
            let values = format(values: segment)
            let d = !values.isEmpty ? delimeter : .none
            
            return "\(cmd)\(d.rawValue)\(values)"
        }
        
        func format(values s: DOM.Path.Segment) -> String {
            switch s {
            case .move(let m, _): return format(m)
            case .line(let l, _): return format(l)
            case .horizontal(let h, _): return format(h)
            case .vertical(let v, _): return format(v)
            case .cubic(let c, _): return format(c)
            case .cubicSmooth(let c, _): return format(c)
            case .quadratic(let q, _): return format(q)
            case .quadraticSmooth(let q, _): return format(q)
            case .arc(let a, _): return format(a)
            case .close: return ""
            }
        }
        
        func format(command s: DOM.Path.Segment) -> String {
            let cmd = command(for: s)
            return String(cmd.rawValue)
        }
        
        func command(for s: DOM.Path.Segment) -> Command {
            switch s {
            case .move(_, let s):
                return (s == .absolute) ? .move : .moveRelative
            case .line(_, let s):
                return (s == .absolute) ? .line : .lineRelative
            case .horizontal(_, let s):
                return (s == .absolute) ? .horizontal : .horizontalRelative
            case .vertical(_, let s):
                return (s == .absolute) ? .vertical : .verticalRelative
            case .cubic(_, let s):
                return (s == .absolute) ? .cubic : .cubicRelative
            case .cubicSmooth(_, let s):
                return (s == .absolute) ? .cubicSmooth : .cubicSmoothRelative
            case .quadratic(_, let s):
                return (s == .absolute) ? .quadratic : .quadraticRelative
            case .quadraticSmooth(_, let s):
                return (s == .absolute) ? .quadraticSmooth : .quadraticSmoothRelative
            case .arc(_, let s):
                return (s == .absolute) ? .arc : .arcRelative
            case .close:
                return .close
            }
        }
        
        func format(_ m: DOM.Path.Move) -> String {
            return coordinateFormatter.format(m.x, m.y)
        }
        
        func format(_ l: DOM.Path.Line) -> String {
            return coordinateFormatter.format(l.x, l.y)
        }
        
        func format(_ h: DOM.Path.Horizontal) -> String {
            return coordinateFormatter.format(h.x)
        }
        
        func format(_ v: DOM.Path.Vertical) -> String {
            return coordinateFormatter.format(v.y)
        }
        
        func format(_ c: DOM.Path.Cubic) -> String {
            return coordinateFormatter.format(c.x, c.y, c.x1, c.y1, c.x2, c.y2)
        }
        
        func format(_ c: DOM.Path.CubicSmooth) -> String {
            return coordinateFormatter.format(c.x, c.y, c.x2, c.y2)
        }
        
        func format(_ q: DOM.Path.Quadratic) -> String {
            return coordinateFormatter.format(q.x, q.y, q.x1, q.y1)
        }
        
        func format(_ q: DOM.Path.QuadraticSmooth) -> String {
            return coordinateFormatter.format(q.x, q.y)
        }
        
        func format(_ a: DOM.Path.Arc) -> String {
            
            let coords = coordinateFormatter.format(a.x, a.y, a.rx, a.ry, a.rotate)
            
            let large = a.large ? "1" : "0"
            let sweep = a.sweep ? "1" : "0"
            
            return "\(coords) \(large) \(sweep)"
        }
    }
}
