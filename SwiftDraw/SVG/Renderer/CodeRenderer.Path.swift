//
//  CodeRenderer.Path.swift
//  SwiftVG
//
//  Created by Simon Whitty on 6/4/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//


enum CodePath: Equatable {
    case ellipse(within: Builder.Rect)
    case rect(rect: Builder.Rect, radii: Builder.Size)
    case lines(between: [Builder.Point])
    case polygon(points: [Builder.Point])
    case path(from: Builder.Path)
    case compound(paths: [CodePath])
    
    static func ==(lhs: CodePath, rhs: CodePath) -> Bool {
        switch (lhs, rhs) {
        case (.ellipse(let lVal), .ellipse(let rVal)):
            return lVal == rVal
        case (.rect(let lVal), .rect(let rVal)):
            return lVal == rVal
        case (.lines(let lVal), .lines(let rVal)):
            return lVal == rVal
        case (.polygon(let lVal), .polygon(let rVal)):
            return lVal == rVal
        case (.path(let lVal), .path(let rVal)):
            return lVal == rVal
        case (.compound(let lVal), .compound(let rVal)):
            return lVal == rVal
        default:
            return false
        }
    }
}
