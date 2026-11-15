//
//  CGPath+Segment.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 10/3/17.
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

#if canImport(CoreGraphics)
import CoreText
import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

extension CGPath {
    func doApply(action: @escaping (CGPathElement)->()) {
        var action = action
        withUnsafeMutablePointer(to: &action) { action in
            apply(info: action) {
                let action = $0!.bindMemory(to: ((CGPathElement)->()).self, capacity: 1).pointee
                action($1.pointee)
            }
        }
    }
}

extension CGPath {
    enum Segment: Equatable {
        case move(CGPoint)
        case line(CGPoint)
        case quad(CGPoint, CGPoint)
        case cubic(CGPoint, CGPoint, CGPoint)
        case close
    }

    func segments() -> [Segment] {
        var segments = [Segment]()
        self.doApply {
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
            @unknown default:
                ()
            }
        }
        return segments
    }
}

extension CGPath {

    func makePath() -> LayerTree.Path {
        let s = segments()
        return LayerTree.Path(
            s.map(Self.makeSegment)
        )
    }

    static func makeSegment(for segment: Segment) -> LayerTree.Path.Segment {
        switch segment {
        case .move(let point):
            return .move(to: .init(point))
        case .line(let point):
            return .line(to: .init(point))
        case .cubic(let control1, let control2, let point):
            return .cubic(to: .init(point), control1: .init(control1), control2: .init(control2))
        case .close:
            return .close
        case .quad(let control1, let point):
            return .cubic(to: .init(point), control1: .init(control1), control2: .init(control1))
        }
    }
}

private extension LayerTree.Point {
    init(_ p: CGPoint) {
        self.init(LayerTree.Float(p.x),
                  LayerTree.Float((p.y)))
    }
}

extension String {

    func toLine(font: CTFont) -> CTLine {
        let attributes = [kCTFontAttributeName: font]
        let attString = CFAttributedStringCreate(nil, self as CFString, attributes as CFDictionary)!
        return CTLineCreateWithAttributedString(attString)
    }

    /// The glyph outlines of the text, with the bold and oblique each run's font needs synthesized
    func toPath(font: CTFont, synthesis: (CTFont) -> LayerTree.FontSynthesis = { _ in [] }) -> CGPath? {
        let line = toLine(font: font)
        let glyphRuns = CTLineGetGlyphRuns(line)

        var ascent = CGFloat(0)
        var descent = CGFloat(0)
        var leading = CGFloat(0)
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let baseline = ascent


        let path = CGMutablePath()
        // synthesized bold widens each glyph's advance, moving the glyphs after it
        var boldAdvance = CGFloat(0)

        for idx in 0..<CFArrayGetCount(glyphRuns) {
            let val = CFArrayGetValueAtIndex(glyphRuns, idx)
            let run = unsafeBitCast(val, to: CTRun.self)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = resolveRunFont(attributes: attributes, fallback: font)
            let runSynthesis = synthesis(runFont)
            let boldOffset = runSynthesis.contains(.bold) ? Self.syntheticBoldOffset(for: runFont) : 0
            let skew = runSynthesis.contains(.oblique) ? Self.syntheticObliqueTransform : .identity

            for idx in 0..<CTRunGetGlyphCount(run) {
                let glyphRange = CFRange(location: idx, length: 1)
                var glyph: CGGlyph = 0
                var position: CGPoint = .zero
                CTRunGetGlyphs(run, glyphRange, &glyph)
                CTRunGetPositions(run, glyphRange, &position)
                var t = skew
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyph, &t) {
                    let t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: position.x + boldAdvance, ty: baseline)
                    let t1 = t.translatedBy(x: 0, y: baseline)
                    path.addPath(glyphPath, transform: t1)
                    if boldOffset > 0 {
                        // a second copy, offset; filled nonzero, the two copies merge
                        path.addPath(glyphPath, transform: t1.translatedBy(x: boldOffset, y: 0))
                    }
                }
                boldAdvance += boldOffset
            }
        }

        return path
    }

    /// The width of the text, including the advance synthesized bold adds to each glyph
    func toWidth(font: CTFont, synthesis: (CTFont) -> LayerTree.FontSynthesis = { _ in [] }) -> CGFloat {
        let line = toLine(font: font)
        var width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let glyphRuns = CTLineGetGlyphRuns(line)
        for idx in 0..<CFArrayGetCount(glyphRuns) {
            let run = unsafeBitCast(CFArrayGetValueAtIndex(glyphRuns, idx), to: CTRun.self)
            let runFont = resolveRunFont(attributes: CTRunGetAttributes(run) as NSDictionary, fallback: font)
            if synthesis(runFont).contains(.bold) {
                width += Self.syntheticBoldOffset(for: runFont) * CGFloat(CTRunGetGlyphCount(run))
            }
        }
        return width
    }

    /// WebKit's synthesized bold: each glyph drawn again this far to the right
    static func syntheticBoldOffset(for font: CTFont) -> CGFloat {
        CTFontGetSize(font) * CGFloat(LayerTree.FontSynthesis.boldOffsetRatio)
    }

    /// WebKit's synthesized oblique: glyphs skewed about the baseline (in glyph space, y up)
    static var syntheticObliqueTransform: CGAffineTransform {
        let angle = CGFloat(LayerTree.FontSynthesis.obliqueAngle) * .pi / 180
        return CGAffineTransform(a: 1, b: 0, c: tan(angle), d: 1, tx: 0, ty: 0)
    }

    // Use the font CoreText resolved for this run, else fall back to the requested font.
    private func resolveRunFont(attributes: NSDictionary, fallback: CTFont) -> CTFont {
        guard let value = attributes[kCTFontAttributeName] else {
            return fallback
        }
        // CoreFoundation type bridging: ensure it's a CTFont before use.
        if CFGetTypeID(value as CFTypeRef) == CTFontGetTypeID() {
            return unsafeDowncast(value as AnyObject, to: CTFont.self)
        }
        return fallback
    }
}

#endif
