//
//  XMLFormatter.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension Formatter {
    
    // XML Formatter
    struct XML {
        
        var coordinateFormatter = CoordinateFormatter()
        
        static func attributes(for _: DOM.Element) -> [String: String] {
            // common graphic element attributes
            return [:]
        }
    }
    
    struct CoordinateFormatter {
        var delimeter: Delimeter = .space
        var precision: Precision = .capped(max: 5)
        
        enum Precision {
            case capped(max: Int)
            case maximum
        }
        
        enum Delimeter: String {
            case space = " "
            case comma = ","
        }
        
        func format(_ coordinates: DOM.Coordinate...) -> String {
            return coordinates.map { format(Double($0)) }.joined(separator: delimeter.rawValue)
        }
        
        func format(_ c: Double) -> String {
            switch precision {
            case .capped(let max):
                return format(c, capped: max)
            default:
                return String(describing: c)
            }
        }
        
        func format(integer n: Double, maxDigits _: Int) -> String {
            assert(n.sign == .plus)
            return String(format: "%d", Int(n))
        }
        
        func format(fraction n: Double, maxDigits: Int) -> String {
            assert(n.sign == .plus)
            
            let min = pow(Double(10), Double(-maxDigits)) - DBL_EPSILON
            
            if n < min {
                return ""
            } else {
                let s = String(format: "%.\(maxDigits)g", n)
                let idx = s.index(s.startIndex, offsetBy: 1)
                return s.substring(from: idx)
            }
        }
        
        func format(_ c: Double, capped: Int) -> String {
            let sign: String
            let n: (Double, Double)
            
            if c.sign == .minus {
                sign = "-"
                n = modf(abs(c))
            } else {
                sign = ""
                n = modf(c)
            }
            
            let integer = Int(n.0)
            let fraction = format(fraction: n.1, maxDigits: capped)
            
            return "\(sign)\(integer)\(fraction)"
        }
    }
}
