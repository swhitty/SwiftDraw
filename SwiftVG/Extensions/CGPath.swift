//
//  CGPath.swift
//  SwiftVG
//
//  Created by Simon Whitty on 10/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics

extension CGPath {
    func apply(action: @escaping (CGPathElement)->()) {
        var action = action
        apply(info: &action) {
            let action = $0!.bindMemory(to: ((CGPathElement)->()).self, capacity: 1).pointee
            action($1.pointee)
        }
    }
}

extension CGPath {
    enum Segment {
        case move(CGPoint)
        case line(CGPoint)
        case quad(CGPoint, CGPoint)
        case cubic(CGPoint, CGPoint, CGPoint)
        case close
    }
    
    func segments() -> [Segment] {
        var segments = [Segment]()
        self.apply {
            let p = $0
            switch (p.type) {
            case .moveToPoint:
                segments.append(Segment.move(p.points[0]))
            case .addLineToPoint:
                segments.append(Segment.line(p.points[0]))
            case .addQuadCurveToPoint:
                segments.append(Segment.quad(p.points[0], p.points[1]))
            case .addCurveToPoint:
                segments.append(Segment.cubic(p.points[0], p.points[1], p.points[2]))
            case .closeSubpath:
                segments.append(Segment.close)
            }
        }
        return segments
    }
}
