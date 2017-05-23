//
//  CGPath.swift
//  SwiftVG
//
//  Created by Simon Whitty on 10/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import CoreGraphics
import CoreText
import Foundation

extension CGPath {
    func applyA(action: @escaping (CGPathElement)->()) {
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
    
    func segmentsA() -> [Segment] {
        var segments = [Segment]()
        self.applyA {
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

extension String {
    
    func toPath(font: CTFont) -> CGPath {
        let attrs: [String: AnyObject] = [kCTFontAttributeName as String: font]
        let attString = CFAttributedStringCreate(nil, self as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attString)
        let glyphRuns = CTLineGetGlyphRuns(line)
        
        let path = CGMutablePath()
        
        for idx in 0..<CFArrayGetCount(glyphRuns) {
            let val = CFArrayGetValueAtIndex(glyphRuns, idx)
            let run = unsafeBitCast(val, to: CTRun.self)
            
            for idx in 0..<CTRunGetGlyphCount(run) {
                let glyphRange = CFRange(location: idx, length: 1)
                var glyph: CGGlyph = 0
                var position: CGPoint = .zero
                CTRunGetGlyphs(run, glyphRange, &glyph)
                CTRunGetPositions(run, glyphRange, &position)
                if let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) {
                    let t = CGAffineTransform(translationX: position.x, y: position.y)
                    path.addPath(glyphPath, transform: t)
                }
            }
        }
        return path
    }
}
