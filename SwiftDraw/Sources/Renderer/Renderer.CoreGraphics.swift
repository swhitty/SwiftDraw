//
//  Renderer.CoreGraphics.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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
import Foundation
import CoreText
import Accelerate
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import SwiftDrawDOM

struct CGTypes: RendererTypes, Sendable {
    typealias Float = CGFloat
    typealias Point = CGPoint
    typealias Size = CGSize
    typealias Rect = CGRect
    typealias Color = CGColor
    typealias Gradient = CGGradient
    typealias Path = CGPath
    typealias Pattern = CGTransformingPattern
    typealias Transform = CGAffineTransform
    typealias BlendMode = CGBlendMode
    typealias FillRule = CGPathFillRule
    typealias LineCap = CGLineCap
    typealias LineJoin = CGLineJoin
    typealias Image = CGImage
}

struct CGTransformingPattern: Hashable {

    var bounds: CGRect
    var contents: [RendererCommand<CGTypes>]
    /// patternTransform: pattern space to the user space of the filled element
    var transform: CGAffineTransform

    init(bounds: CGRect, contents: [RendererCommand<CGTypes>], transform: CGAffineTransform = .identity) {
        self.bounds = bounds
        self.contents = contents
        self.transform = transform
    }

    func draw(_ ctx: CGContext) {
        // with .noDistortion, CoreGraphics draws a cell whose size in device pixels is fractional
        // without clipping it to the tile, so its contents would spill into the next tile
        ctx.clip(to: bounds)
        // the cell is a bitmap whose default space is the identity: a pattern drawn inside the cell
        // is relative to it, including the device scale the cell is drawn at
        let renderer = CGRenderer(context: ctx, baseCTM: .identity)
        renderer.perform(contents)
    }
}

struct CGProvider: RendererTypeProvider {

    typealias Types = CGTypes

    func createFloat(from float: LayerTree.Float) -> CGFloat {
        return CGFloat(float)
    }

    func createPoint(from point: LayerTree.Point) -> CGPoint {
        return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
    }

    func createSize(from size: LayerTree.Size) -> CGSize {
        return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }

    func createRect(from rect: LayerTree.Rect) -> CGRect {
        return CGRect(
            x: CGFloat(rect.x),
            y: CGFloat(rect.y),
            width: CGFloat(rect.width),
            height: CGFloat(rect.height)
        )
    }

    func createColor(from color: LayerTree.Color) -> CGColor {
        switch color {
        case .none: return createSRGB(r: 0, g: 0, b: 0, a: 0)
        case let .rgba(r, g, b, a, .srgb):
            return createSRGB(
                r: CGFloat(r),
                g: CGFloat(g),
                b: CGFloat(b),
                a: CGFloat(a)
            )
        case let .rgba(r, g, b, a, .p3):
            return createP3(
                r: CGFloat(r),
                g: CGFloat(g),
                b: CGFloat(b),
                a: CGFloat(a)
            )
        case .gray(white: let w, a: let a):
            return createColor(w: CGFloat(w), a: CGFloat(a))
        }
    }

    func createColorSpace(for colorSpace: LayerTree.ColorSpace) -> CGColorSpace {
        switch colorSpace {
        case .srgb:
            return CGColorSpace.sRGBSpace
        case .p3:
            return CGColorSpace.displayP3Space
        }
    }

    func createGradient(from gradient: LayerTree.Gradient) -> CGGradient {
        let colors = gradient.stops.map { createColor(from: $0.color) } as CFArray
        var points = gradient.stops.map { createFloat(from: $0.offset) }

        return CGGradient(
            colorsSpace: createColorSpace(for: gradient.colorSpace),
            colors: colors,
            locations: &points
        )!
    }

    private func createSRGB(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(
            colorSpace: CGColorSpace.sRGBSpace,
            components: [r, g, b, a]
        )!
    }

    private func createP3(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(
            colorSpace: CGColorSpace.displayP3Space,
            components: [r, g, b, a]
        )!
    }

    private func createColor(w: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(
            colorSpace: CGColorSpaceCreateExtendedGray(),
            components: [w, a]
        )!
    }

    func createBlendMode(from mode: LayerTree.BlendMode) -> CGBlendMode {
        switch mode {
        case .normal: return .normal
        case .copy: return .copy
        case .sourceIn: return .sourceIn
        case .destinationIn: return .destinationIn
        }
    }
    func createTransform(from transform: LayerTree.Transform.Matrix) -> CGAffineTransform {
        return CGAffineTransform(
            a: CGFloat(transform.a),
            b: CGFloat(transform.b),
            c: CGFloat(transform.c),
            d: CGFloat(transform.d),
            tx: CGFloat(transform.tx),
            ty: CGFloat(transform.ty)
        )
    }

    func createPath(from shape: LayerTree.Shape) -> CGPath {
        switch shape {
        case .line(let points):
            let path = CGMutablePath()
            path.addLines(between: points.map { createPoint(from: $0) })
            return path
        case .rect(let frame, let radii):
            return CGPath(
                roundedRect: createRect(from: frame),
                cornerWidth: createFloat(from: radii.width),
                cornerHeight: createFloat(from: radii.height),
                transform: nil
            )
        case .ellipse(let frame):
            return CGPath(ellipseIn: createRect(from: frame), transform: nil)
        case .polygon(let points):
            let path = CGMutablePath()
            path.addLines(between: points.map { createPoint(from: $0) })
            path.closeSubpath()
            return path
        case .path(let path):
            return createPath(from: path)
        }
    }

    private func createPath(from path: LayerTree.Path) -> CGPath {
        let cgPath = CGMutablePath()
        for s in path.segments {
            switch s {
            case .move(let p):
                cgPath.move(to: createPoint(from: p))
            case .line(let p):
                cgPath.addLine(to: createPoint(from: p))
            case .cubic(let p, let cp1, let cp2):
                cgPath.addCurve(
                    to: createPoint(from: p),
                    control1: createPoint(from: cp1),
                    control2: createPoint(from: cp2)
                )
            case .close:
                cgPath.closeSubpath()
            }
        }
        return cgPath
    }

    func createPath(from subPaths: [CGPath]) -> CGPath {
        let cgPath = CGMutablePath()

        for path in subPaths {
            cgPath.addPath(path)
        }

        return cgPath
    }

    func createPath(from run: LayerTree.GlyphRun) -> Types.Path? {
        Self.createGlyphPath(from: run)
    }

    /// The outlines of a run of glyphs at their positions, with the bold and oblique its face needs synthesized
    static func createGlyphPath(from run: LayerTree.GlyphRun) -> CGPath? {
        let font = createFont(for: run.attributes)
        let face = font.face(named: run.fontName)
        let synthesis = font.synthesis(for: face)
        let boldOffset = synthesis.contains(.bold) ? String.syntheticBoldOffset(for: face) : 0
        var skew = synthesis.contains(.oblique) ? String.syntheticObliqueTransform : .identity
        // glyph space is y up: flip it about the baseline, and stretch it for spacingAndGlyphs
        let flip = CGAffineTransform(a: CGFloat(run.scaleX), b: 0, c: 0, d: -1, tx: 0, ty: 0)
        let path = CGMutablePath()
        for (glyph, position) in zip(run.glyphs, run.positions) {
            guard let outline = CTFontCreatePathForGlyph(face, CGGlyph(glyph), &skew) else { continue }
            let origin = CGAffineTransform(translationX: CGFloat(position.x), y: CGFloat(position.y))
            path.addPath(outline, transform: flip.concatenating(origin))
            if boldOffset > 0 {
                // a second copy, offset; filled nonzero, the two copies merge
                path.addPath(
                    outline,
                    transform: flip.concatenating(origin.translatedBy(x: boldOffset * CGFloat(run.scaleX), y: 0))
                )
            }
        }
        return path
    }

    func createPath(
        from text: String,
        at origin: LayerTree.Point,
        with attributes: LayerTree.TextAttributes
    ) -> Types.Path? {
        let font = CGProvider.createFont(for: attributes)
        guard let path = text.toPath(font: font.font, synthesis: font.synthesis(for:)) else { return nil }
        var transform = CGAffineTransform(translationX: createFloat(from: origin.x), y: createFloat(from: origin.y))
        return path.copy(using: &transform)
    }

    private static func createCTFont(
        for font: LayerTree.TextAttributes.Font,
        size: CGFloat,
        weight: Int,
        isItalic: Bool
    ) -> CTFont? {
        switch font {
        case .truetype(let data):
            // an @font-face font is already the face matching the weight and style
            guard let provider = CGDataProvider(data: data as CFData),
                let cgFont = CGFont(provider)
            else { return nil }
            return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        case .name(let name):
            let ctFont = CTFontCreateWithName(name as CFString, size, nil)
            // a family ("Helvetica", also the PostScript name of its regular face): pick the face by weight and slant
            if CTFontCopyFamilyName(ctFont) as String == name {
                guard weight != 400 || isItalic else { return ctFont }
                return createCTFont(family: name, size: size, weight: weight, isItalic: isItalic) ?? ctFont
            }
            // a specific face by PostScript name ("Helvetica-Bold"): used as named
            let postScriptName = CTFontCopyPostScriptName(ctFont) as String
            return postScriptName.caseInsensitiveCompare(name) == .orderedSame ? ctFont : nil
        case .postScript(let name):
            // a local() face, resolved when the layer tree was built
            let ctFont = CTFontCreateWithName(name as CFString, size, nil)
            return CTFontCopyPostScriptName(ctFont) as String == name ? ctFont : nil
        case .synthesized(let font, _):
            return createCTFont(for: font, size: size, weight: weight, isItalic: isItalic)
        }
    }

    /// A font with the bold and oblique each of its faces needs synthesized
    struct SyntheticFont {
        /// The first face, cascading to the others
        var font: CTFont
        /// The synthesis of each face, by PostScript name, in cascade order
        var faces: [(postScriptName: String, synthesis: LayerTree.FontSynthesis)]
        var weight: Int
        var isItalic: Bool
        /// The faces in cascade order
        var faceFonts: [CTFont] = []

        /// The face a run of shaped glyphs is in, by PostScript name: one of the faces, else an
        /// installed font CoreText fell back to
        func face(named name: String) -> CTFont {
            if CTFontCopyPostScriptName(font) as String == name { return font }
            if let face = faceFonts.first(where: { CTFontCopyPostScriptName($0) as String == name }) {
                return face
            }
            return CTFontCreateWithName(name as CFString, CTFontGetSize(font), nil)
        }

        /// The synthesis for a run's font: that of its face, or for a font CoreText substituted for
        /// missing glyphs (a system font), whatever its own weight and slant lack
        func synthesis(for runFont: CTFont) -> LayerTree.FontSynthesis {
            let name = CTFontCopyPostScriptName(runFont) as String
            if let face = faces.first(where: { $0.postScriptName == name }) {
                return face.synthesis
            }
            return CGProvider.fontSynthesis(for: runFont, weight: weight, isItalic: isItalic)
        }
    }

    /// The synthesis an installed face needs to be drawn at a CSS weight and slant, from its CoreText
    /// traits, as WebKit decides it for system fonts (e.g. Chalkduster has one face, so its bold and
    /// italic are synthesized; Impact is already heavy, so only its italic is).
    static func fontSynthesis(for font: CTFont, weight: Int, isItalic: Bool) -> LayerTree.FontSynthesis {
        let traits = CTFontCopyTraits(font) as NSDictionary
        let coreTextWeight = (traits[kCTFontWeightTrait] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
        let isBold = coreTextWeight >= self.coreTextWeight(for: LayerTree.FontSynthesis.boldThreshold)
        return LayerTree.FontSynthesis(
            weight: weight,
            isItalic: isItalic,
            faceWeight: isBold ? LayerTree.FontSynthesis.boldThreshold : 400,
            faceIsItalic: CTFontGetSymbolicTraits(font).contains(.traitItalic)
        )
    }

    private static func fontSynthesis(
        for font: LayerTree.TextAttributes.Font,
        ctFont: CTFont,
        weight: Int,
        isItalic: Bool
    ) -> LayerTree.FontSynthesis {
        switch font {
        case .synthesized(_, let synthesis):
            return synthesis
        case .name:
            return fontSynthesis(for: ctFont, weight: weight, isItalic: isItalic)
        case .truetype, .postScript:
            // an @font-face face that has the weight and slant it was matched for
            return []
        }
    }

    // CoreText font lookups, one at a time. macOS deadlocks when every thread of Swift's cooperative pool is in
    // a font lookup at once: each waits on a synchronous XPC request to the font server that is never answered,
    // e.g. when as many tasks as there are cores render text, or tests run in parallel. One lookup at a time
    // never does. Line layout (CTLine), fallback fonts included, is not affected.
    private static let fontLookup = Mutex(())

    /// The PostScript name of an installed face, matched by PostScript name or full name, case-insensitively
    /// (`local()` in `@font-face`); nil when no such face is installed. CoreText substitutes another font
    /// for an unknown name, so the match is checked.
    static func installedFontPostScriptName(_ name: String) -> String? {
        fontLookup.withLock { _ in
            makeInstalledFontPostScriptName(name)
        }
    }

    private static func makeInstalledFontPostScriptName(_ name: String) -> String? {
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        let postScriptName = CTFontCopyPostScriptName(font) as String
        let fullName = CTFontCopyFullName(font) as String
        guard
            postScriptName.caseInsensitiveCompare(name) == .orderedSame
                || fullName.caseInsensitiveCompare(name) == .orderedSame
        else {
            return nil
        }
        return postScriptName
    }

    /// The face of a system font family closest to a CSS weight and slant (e.g. Helvetica 700 is
    /// Helvetica-Bold, 300 is Helvetica-Light, italic is Helvetica-Oblique). Faces of normal width are
    /// matched as CSS Fonts 4 §5.2 does: slant first, then weight (650 picks a bold face over a
    /// semibold one). Within `fontLookup`.
    private static func createCTFont(family: String, size: CGFloat, weight: Int, isItalic: Bool) -> CTFont? {
        if let descriptor = matchFace(family: family, weight: weight, isItalic: isItalic) {
            return CTFontCreateWithFontDescriptor(descriptor, size, nil)
        }
        return createCTFontByTraits(family: family, size: size, weight: weight, isItalic: isItalic)
    }

    /// CSS font matching over the installed faces of a family; nil when CoreText lists none.
    private static func matchFace(family: String, weight: Int, isItalic: Bool) -> CTFontDescriptor? {
        let request = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        guard let matches = CTFontDescriptorCreateMatchingFontDescriptors(request, nil) as? [CTFontDescriptor] else {
            return nil
        }
        let faces = matches.compactMap {
            descriptor -> (descriptor: CTFontDescriptor, weight: Int, isItalic: Bool, width: CGFloat)? in
            guard CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String == family,
                let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [CFString: Any]
            else {
                return nil
            }
            let coreTextWeight = (traits[kCTFontWeightTrait] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let width = (traits[kCTFontWidthTrait] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let symbolic =
                (traits[kCTFontSymbolicTrait] as? NSNumber).map { CTFontSymbolicTraits(rawValue: $0.uint32Value) } ?? []
            return (descriptor, cssWeight(for: coreTextWeight), symbolic.contains(.traitItalic), width)
        }
        // font-stretch: normal, the narrowest distance from the normal width
        guard let bestWidth = faces.map({ abs($0.width) }).min() else { return nil }
        let normalWidth = faces.filter { abs($0.width) == bestWidth }
        // font-style: italic and oblique faces are both italic to CoreText; else the other slant
        let slanted = normalWidth.filter { $0.isItalic == isItalic }
        let candidates = slanted.isEmpty ? normalWidth : slanted
        return candidates.min {
            LayerTree.Builder.fontWeightRank($0.weight...$0.weight, for: weight)
                < LayerTree.Builder.fontWeightRank($1.weight...$1.weight, for: weight)
        }?.descriptor
    }

    /// The CSS weight of a CoreText weight trait, the inverse of `coreTextWeight(for:)`
    static func cssWeight(for coreTextWeight: CGFloat) -> Int {
        let points = coreTextWeightPoints
        let w = min(max(coreTextWeight, -1), 1)
        guard let upper = points.firstIndex(where: { $0.ct >= w }), upper > 0 else { return Int(points[0].css) }
        let (a, b) = (points[upper - 1], points[upper])
        return Int((a.css + (b.css - a.css) * (w - a.ct) / (b.ct - a.ct)).rounded())
    }

    /// The face CoreText matches to the weight and slant traits
    private static func createCTFontByTraits(family: String, size: CGFloat, weight: Int, isItalic: Bool) -> CTFont? {
        var traits: [CFString: Any] = [kCTFontWeightTrait: coreTextWeight(for: weight)]
        if isItalic {
            traits[kCTFontSymbolicTrait] = CTFontSymbolicTraits.traitItalic.rawValue
        }
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [
                kCTFontFamilyNameAttribute: family,
                kCTFontTraitsAttribute: traits,
            ] as CFDictionary
        )
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        // CoreText falls back to another family when this one is not installed
        guard CTFontCopyFamilyName(font) as String == family else { return nil }
        return font
    }

    /// CSS weights (1–1000) on CoreText's weight trait (−1…1), at the points of `NSFont.Weight`
    /// (ultraLight 100 … black 900), interpolated between them.
    static func coreTextWeight(for weight: Int) -> CGFloat {
        let points = coreTextWeightPoints
        let w = min(max(CGFloat(weight), 1), 1000)
        guard let upper = points.firstIndex(where: { $0.css >= w }), upper > 0 else { return points[0].ct }
        let (a, b) = (points[upper - 1], points[upper])
        return a.ct + (b.ct - a.ct) * (w - a.css) / (b.css - a.css)
    }

    private static let coreTextWeightPoints: [(css: CGFloat, ct: CGFloat)] = [
        (1, -1), (100, -0.8), (200, -0.6), (300, -0.4), (400, 0),
        (500, 0.23), (600, 0.3), (700, 0.4), (800, 0.56), (900, 0.62), (1000, 1),
    ]

    static func createCTFont(for attributes: LayerTree.TextAttributes) -> CTFont {
        createFont(for: attributes).font
    }

    static func createFont(for attributes: LayerTree.TextAttributes) -> SyntheticFont {
        createFont(
            for: attributes.font,
            size: attributes.size,
            weight: attributes.weight,
            isItalic: attributes.isItalic
        )
    }

    static func createCTFont(
        for fonts: [LayerTree.TextAttributes.Font],
        size: Float,
        weight: Int = 400,
        isItalic: Bool = false
    ) -> CTFont {
        createFont(for: fonts, size: size, weight: weight, isItalic: isItalic).font
    }

    static func createFont(
        for fonts: [LayerTree.TextAttributes.Font],
        size: Float,
        weight: Int = 400,
        isItalic: Bool = false
    ) -> SyntheticFont {
        var font: SyntheticFont?
        fontLookup.withLock { _ in
            font = makeFont(for: fonts, size: size, weight: weight, isItalic: isItalic)
        }
        return font!
    }

    // within fontLookup
    private static func makeFont(
        for fonts: [LayerTree.TextAttributes.Font],
        size: Float,
        weight: Int,
        isItalic: Bool
    ) -> SyntheticFont {
        let cgSize = CGFloat(size)
        var faces = fonts.compactMap { font -> (CTFont, LayerTree.FontSynthesis)? in
            guard let ctFont = createCTFont(for: font, size: cgSize, weight: weight, isItalic: isItalic) else {
                return nil
            }
            return (ctFont, fontSynthesis(for: font, ctFont: ctFont, weight: weight, isItalic: isItalic))
        }
        if faces.isEmpty {
            let fallback =
                createCTFont(for: .name("Times"), size: cgSize, weight: weight, isItalic: isItalic)
                ?? CTFontCreateWithName("Times" as CFString, cgSize, nil)
            faces = [(fallback, fontSynthesis(for: fallback, weight: weight, isItalic: isItalic))]
        }
        var font = faces[0].0
        if faces.count > 1 {
            let descriptors = faces.dropFirst().map { CTFontCopyFontDescriptor($0.0) }
            let cascade = CTFontDescriptorCreateWithAttributes(
                [kCTFontCascadeListAttribute: descriptors] as CFDictionary
            )
            font = CTFontCreateCopyWithAttributes(font, cgSize, nil, cascade)
        }
        return SyntheticFont(
            font: font,
            faces: faces.map { (CTFontCopyPostScriptName($0.0) as String, $0.1) },
            weight: weight,
            isItalic: isItalic,
            faceFonts: faces.map(\.0)
        )
    }

    func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> CGTransformingPattern {
        let bounds = createRect(from: pattern.frame)
        return CGTransformingPattern(
            bounds: bounds,
            contents: contents,
            transform: createTransform(from: pattern.transform)
        )
    }

    func createFillRule(from rule: LayerTree.FillRule) -> CGPathFillRule {
        switch rule {
        case .nonzero:
            return .winding
        case .evenodd:
            return .evenOdd
        }
    }

    func createLineCap(from cap: LayerTree.LineCap) -> CGLineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }

    func createLineJoin(from join: LayerTree.LineJoin) -> CGLineJoin {
        switch join {
        case .bevel: return .bevel
        case .round: return .round
        case .miter: return .miter
        }
    }

    func createImage(from image: LayerTree.Image) -> CGImage? {
        switch image.bitmap {
        case .jpeg(let d):
            return CGImage.from(data: d)
        case .png(let d):
            return CGImage.from(data: d)
        }
    }

    func createSize(from image: CGImage) -> LayerTree.Size {
        LayerTree.Size(
            LayerTree.Float(image.width),
            LayerTree.Float(image.height)
        )
    }

    func getBounds(from shape: LayerTree.Shape) -> LayerTree.Rect {
        let bounds = createPath(from: shape).boundingBoxOfPath
        return LayerTree.Rect(
            x: LayerTree.Float(bounds.origin.x),
            y: LayerTree.Float(bounds.origin.y),
            width: LayerTree.Float(bounds.width),
            height: LayerTree.Float(bounds.height)
        )
    }
}

//TODO: replace with CG implementation
private extension CGImage {
    static func from(data: Data) -> CGImage? {
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        var rect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }
}

struct CGRenderer: Renderer {
    typealias Types = CGTypes

    private let rootContext: CGContext
    private let rootCTM: CGAffineTransform
    private let filterLayers = CGFilterLayerStack()
    let maxFilterLayerPixels: Int
    let filters: CGFilterLayerDraw?

    // drawing goes into the innermost offscreen filter layer, if any
    var ctx: CGContext { filterLayers.context ?? rootContext }

    /// The current context's default coordinate space, which CGPattern matrices are relative to.
    /// Offscreen filter layers are bitmaps whose base space is the identity.
    var baseCTM: CGAffineTransform { filterLayers.context == nil ? rootCTM : .identity }

    /// - Parameter baseCTM: the context's default space; defaults to the current CTM.
    ///   Pass the CTM from before any transform the caller applied itself, e.g. a top-left flip.
    /// - Parameter filters: a cache of filtered results to reuse and keep, when the same commands are drawn repeatedly.
    init(
        context: CGContext,
        baseCTM: CGAffineTransform? = nil,
        maxFilterLayerPixels: Int = CGRenderer.defaultMaxFilterLayerPixels,
        filters: CGFilterLayerDraw? = nil
    ) {
        self.rootContext = context
        self.rootCTM = baseCTM ?? context.ctm
        self.maxFilterLayerPixels = maxFilterLayerPixels
        self.filters = filters
    }

    // With a cache, a filter layer drawn before in the same device space is composited from it
    // and its commands skipped. Cache keys are command indices, so these must be the cache's commands.
    func perform(_ commands: [RendererCommand<CGTypes>]) {
        guard filters != nil else {
            for command in commands { perform(command) }
            return
        }
        var index = 0
        while index < commands.count {
            if case .pushFilterLayer(let filter) = commands[index] {
                if let end = RendererCommand.matchingPop(in: commands, from: index),
                    drawCachedFilterLayer(filter, index: index)
                {
                    index = end + 1
                    continue
                }
                filterLayers.pendingIndex = index
            }
            perform(commands[index])
            index += 1
        }
    }

    func pushState() {
        ctx.saveGState()
    }

    func popState() {
        ctx.restoreGState()
    }

    func pushTransparencyLayer() {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    }

    func popTransparencyLayer() {
        ctx.endTransparencyLayer()
    }

    func concatenate(transform: CGAffineTransform) {
        ctx.concatenate(transform)
    }

    func translate(tx: CGFloat, ty: CGFloat) {
        ctx.translateBy(x: tx, y: ty)
    }

    func rotate(angle: CGFloat) {
        ctx.rotate(by: angle)
    }

    func scale(sx: CGFloat, sy: CGFloat) {
        ctx.scaleBy(x: sx, y: sy)
    }

    func setFill(color: CGColor) {
        ctx.setFillColor(color)
    }

    func setFill(pattern: CGTransformingPattern) {
        let patternSpace = CGColorSpace(patternBaseSpace: nil)!
        ctx.setFillColorSpace(patternSpace)
        var alpha: CGFloat = 1.0

        let cgPattern = CGPattern.make(
            bounds: pattern.bounds,
            matrix: pattern.transform.concatenating(ctx.ctm.concatenating(baseCTM.inverted())),
            step: pattern.bounds.size,
            tiling: .noDistortion,
            isColored: true,
            draw: pattern.draw
        )
        ctx.setFillPattern(cgPattern, colorComponents: &alpha)
    }

    func setStroke(color: CGColor) {
        ctx.setStrokeColor(color)
    }

    func setLine(width: CGFloat) {
        ctx.setLineWidth(width)
    }

    func setLine(cap: CGLineCap) {
        ctx.setLineCap(cap)
    }

    func setLine(join: CGLineJoin) {
        ctx.setLineJoin(join)
    }

    func setLine(miterLimit: CGFloat) {
        ctx.setMiterLimit(miterLimit)
    }

    func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        ctx.setLineDash(phase: phase, lengths: lengths)
    }

    func setClip(path: CGPath, rule: CGPathFillRule) {
        ctx.addPath(path)
        ctx.clip(using: rule)
    }

    // The mask contents are drawn into a greyscale bitmap covering the visible clip in device pixels, starting
    // black (fully masked). Its grey levels become the alpha of the clip. Vector contexts (PDF) get a 2x bitmap.
    func clip(toMask contents: [RendererCommand<CGTypes>]) {
        let visible = ctx.boundingBoxOfClipPath
        guard !visible.isNull, !visible.isEmpty else { return }
        guard !visible.isInfinite else {
            // no bounds to size the mask by: leave the contents unmasked
            return
        }

        let toDevice = ctx.userSpaceToDeviceSpaceTransform
        let deviceRect = visible.applying(toDevice).integral
        let oversample: CGFloat = ctx.isBitmapContext ? 1 : 2
        guard
            let mask = CGContext.makeLuminanceMask(
                deviceRect: deviceRect,
                oversample: oversample,
                maxPixels: CGRenderer.maxMaskPixels
            )
        else {
            ctx.clip(to: .zero)
            return
        }
        mask.concatenate(toDevice)
        // the bitmap's default space is its pixel grid: CGPattern matrices are relative to that
        CGRenderer(context: mask, baseCTM: .identity).perform(contents)

        guard let image = mask.makeImage() else {
            ctx.clip(to: .zero)
            return
        }
        ctx.concatenate(toDevice.inverted())
        ctx.clip(to: deviceRect, mask: image)
        ctx.concatenate(toDevice)
    }

    static let maxMaskPixels = 16_777_216

    func setAlpha(_ alpha: CGFloat) {
        ctx.setAlpha(alpha)
    }

    func setBlend(mode: CGBlendMode) {
        ctx.setBlendMode(mode)
    }

    func stroke(path: CGPath) {
        ctx.addPath(path)
        ctx.strokePath()
    }

    func clipStrokeOutline(path: CGPath) {
        ctx.addPath(path)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
    }

    func fill(path: CGPath, rule: CGPathFillRule) {
        ctx.addPath(path)
        ctx.fillPath(using: rule)
    }

    func draw(image: CGImage, in rect: CGRect) {
        pushState()
        translate(tx: rect.minX, ty: rect.maxY)
        scale(sx: 1, sy: -1)
        pushState()
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        popState()
        popState()
    }

    func draw(linear gradient: CGGradient, from start: CGPoint, to end: CGPoint) {
        ctx.drawLinearGradient(
            gradient,
            start: start,
            end: end,
            options: [.drawsAfterEndLocation, .drawsBeforeStartLocation]
        )
    }

    func draw(
        radial gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat
    ) {
        ctx.drawRadialGradient(
            gradient,
            startCenter: startCenter,
            startRadius: startRadius,
            endCenter: endCenter,
            endRadius: endRadius,
            options: [.drawsAfterEndLocation, .drawsBeforeStartLocation]
        )
    }

    // The following commands are drawn into a bitmap covering the filter region in device pixels,
    // intersected with the visible clip grown by how far the filter moves pixels (blur extent, offsets).
    // The result is composited back clipped to the region. Over maxFilterLayerPixels the bitmap is rendered
    // at a reduced scale (deviations and offsets scaled to match) and drawn back up, so large exports stay
    // filtered without unbounded allocations. SD2's blur chains are blurred in place; other filters evaluate
    // their primitive tree (SD12), which keeps several bitmaps alive: the budget is shared between them.
    func pushFilterLayer(_ filter: LayerTree.FilterLayer) {
        let parent = ctx
        let geometry = FilterLayerGeometry(
            filter: filter,
            parent: parent,
            maxFilterLayerPixels: maxFilterLayerPixels,
            isVector: filters?.isVector(parent) ?? !parent.isBitmapContext
        )
        let cacheIndex = filterLayers.pendingIndex
        filterLayers.pendingIndex = nil

        parent.saveGState()
        parent.clip(to: geometry.region)

        // empty clip: draw nothing and allocate nothing
        guard let deviceRect = geometry.deviceRect else {
            parent.clip(to: .zero)
            filterLayers.entries.append(CGFilterLayer())
            return
        }

        // blurs too small to change a pixel (every box size 1) are a pass-through:
        // draw straight into the parent, clipped to the region
        if geometry.isPassThrough {
            filterLayers.entries.append(CGFilterLayer())
            return
        }

        // missing from the cache, to be filled in the background: drawn unfiltered for now
        if let filters, filters.defersMisses, cacheIndex != nil {
            filters.deferMiss()
            filterLayers.entries.append(CGFilterLayer())
            return
        }

        // PDF and other vector contexts: filtered groups are rasterized at 2x (2 px per point)
        guard
            var layer = CGFilterLayer.make(
                deviceRect: deviceRect,
                deviations: geometry.deviations,
                maxPixels: geometry.maxPixels,
                oversample: geometry.oversample,
                colorSpace: geometry.colorSpace
            )
        else {
            // empty clip or region: draw nothing and allocate nothing
            parent.clip(to: .zero)
            filterLayers.entries.append(CGFilterLayer())
            return
        }
        if !geometry.isBlurChain {
            layer.filter = filter
            layer.toDevice = geometry.toDevice
        }
        if filters != nil, let cacheIndex {
            layer.cacheKey = geometry.cacheKey(index: cacheIndex)
        }

        layer.offscreen?.concatenate(geometry.toDevice)
        // input outside the region is excluded (it matters under rotation or skew); the edge is anti-aliased
        // once, by the parent clip at composite time
        layer.offscreen?.setShouldAntialias(false)
        layer.offscreen?.clip(to: geometry.region)
        layer.offscreen?.setShouldAntialias(true)
        filterLayers.entries.append(layer)
    }

    // kept with the filter layer just pushed, to rasterize when it is popped
    func setFilterImage(primitive: Int, contents: [RendererCommand<CGTypes>]) {
        guard let last = filterLayers.entries.indices.last,
            filterLayers.entries[last].filter != nil
        else { return }
        filterLayers.entries[last].images[primitive] = contents
    }

    func popFilterLayer() {
        guard let layer = filterLayers.entries.popLast() else { return }
        let parent = ctx

        if let offscreen = layer.offscreen {
            if let filter = layer.filter {
                // this layer's bitmaps stay alive while the image is drawn: filters within it get half the
                // budget, so a chain of feImage references stays within twice the budget in all
                let maxPixels = maxFilterLayerPixels / 2
                offscreen.applyFilter(filter, toPixels: layer.pixelTransform) { index in
                    guard let contents = layer.images[index],
                        case .image(let image) = filter.primitives[index].effect
                    else { return nil }
                    return layer.rasterize(
                        contents,
                        isPixelated: image.isPixelated,
                        colorSpace: offscreen.colorSpace,
                        maxFilterLayerPixels: maxPixels
                    )
                }
            } else {
                for deviation in layer.deviations {
                    offscreen.applyGaussianBlur(
                        CGSize(
                            width: deviation.width * layer.scale,
                            height: deviation.height * layer.scale
                        )
                    )
                }
            }
            if let image = offscreen.makeImage() {
                Self.composite(image, deviceRect: layer.deviceRect, scale: layer.scale, into: parent)
                if let filters, let key = layer.cacheKey {
                    filters.cache.store(.init(key: key, image: image, deviceRect: layer.deviceRect, scale: layer.scale))
                }
            }
        }

        // removes the region clip set by pushFilterLayer
        parent.restoreGState()
    }

    // composites the filter layer's result from the cache, as pushFilterLayer…popFilterLayer would; false on a miss
    private func drawCachedFilterLayer(_ filter: LayerTree.FilterLayer, index: Int) -> Bool {
        guard let filters else { return false }
        let parent = ctx
        let geometry = FilterLayerGeometry(
            filter: filter,
            parent: parent,
            maxFilterLayerPixels: maxFilterLayerPixels,
            isVector: filters.isVector(parent)
        )
        guard geometry.deviceRect != nil, !geometry.isPassThrough,
            let entry = filters.cache.entry(for: geometry.cacheKey(index: index))
        else { return false }
        parent.saveGState()
        parent.clip(to: geometry.region)
        Self.composite(entry.image, deviceRect: entry.deviceRect, scale: entry.scale, into: parent)
        parent.restoreGState()
        return true
    }

    // draws a filter layer's pixels at its device rect
    private static func composite(_ image: CGImage, deviceRect: CGRect, scale: CGFloat, into parent: CGContext) {
        let size = CGSize(
            width: CGFloat(image.width) / scale,
            height: CGFloat(image.height) / scale
        )
        parent.saveGState()
        parent.concatenate(parent.userSpaceToDeviceSpaceTransform.inverted())
        if scale == 1 {
            parent.interpolationQuality = .none
        }
        parent.draw(image, in: CGRect(origin: deviceRect.origin, size: size))
        parent.restoreGState()
    }

    static let defaultMaxFilterLayerPixels = 16_777_216
    static let maxDeviceSpread: CGFloat = 100_000
}

final class CGFilterLayerStack {
    var entries = [CGFilterLayer]()
    // the command index of the pushFilterLayer about to be performed, when drawing with a cache
    var pendingIndex: Int?

    var context: CGContext? {
        entries.last(where: { $0.offscreen != nil })?.offscreen
    }
}

// The device space a filter layer is drawn in, which decides its pixels.
// The region's bitmap covers the region in device pixels, intersected with the visible clip grown by how
// far the filter moves pixels (blur extent, offsets).
struct FilterLayerGeometry {
    var region: CGRect
    var toDevice: CGAffineTransform
    var isBlurChain: Bool
    var deviations: [CGSize]
    var isVector: Bool
    var oversample: CGFloat
    var maxPixels: Int
    var colorSpace: CGColorSpace?
    // nil when nothing is visible
    var deviceRect: CGRect?

    /// - Parameter isVector: rasterize as for a vector context (PDF, SwiftUI Canvas): at 2x, without a colour space
    init(filter: LayerTree.FilterLayer, parent: CGContext, maxFilterLayerPixels: Int, isVector: Bool) {
        self.region = CGRect(
            x: CGFloat(filter.region.x),
            y: CGFloat(filter.region.y),
            width: CGFloat(filter.region.width),
            height: CGFloat(filter.region.height)
        )
        let toDevice = parent.userSpaceToDeviceSpaceTransform
        self.toDevice = toDevice
        // a blur that is not along the device axes (rotation or skew) is sheared by the primitive tree
        self.isBlurChain = filter.isBlurChain && !filter.effects.contains { $0.isSheared(toDevice) }
        self.deviations = isBlurChain ? filter.effects.compactMap { $0.deviceStdDeviation(toDevice) } : []
        self.isVector = isVector
        self.oversample = isVector ? 2 : 1
        // the offscreen itself, plus the bitmaps of the primitive tree
        self.maxPixels = isBlurChain ? maxFilterLayerPixels : maxFilterLayerPixels / (filter.peakBitmapCount + 1)
        // Only a bitmap context has a colour space to match: asking a SwiftUI Canvas or other non-bitmap
        // context for one logs "CGBitmapContextGetColorSpace: invalid context". The layer is sRGB then.
        self.colorSpace = isVector ? nil : parent.colorSpace

        let visible = parent.boundingBoxOfClipPath
        guard !visible.isNull, !visible.isEmpty else {
            self.deviceRect = nil
            return
        }
        var rect = region.applying(toDevice)
        if !visible.isInfinite {
            let spread = filter.deviceSpread(toDevice)
            rect = rect.intersection(visible.applying(toDevice).insetBy(dx: -spread.width, dy: -spread.height))
        }
        self.deviceRect = rect
    }

    // blur chains too small to change a pixel (every box size 1) draw straight into the parent
    var isPassThrough: Bool {
        isBlurChain && !deviations.contains(where: { CGContext.isVisibleBlur($0, scale: oversample) })
    }

    func cacheKey(index: Int) -> CGFilterLayerCache.Key {
        CGFilterLayerCache.Key(
            index: index,
            toDevice: toDevice,
            // the whole pixels drawn: unaffected by rounding in the clips of alike contexts
            deviceRect: (deviceRect ?? .null).integral,
            maxPixels: maxPixels,
            isVector: isVector,
            colorSpace: colorSpace
        )
    }
}

struct CGFilterLayer {
    // nil when contents are drawn directly into the parent context
    var offscreen: CGContext?
    var deviceRect: CGRect = .zero
    var deviations: [CGSize] = []
    // offscreen pixels per device pixel
    var scale: CGFloat = 1
    // a primitive tree to evaluate when popped, with the user space it was resolved in (SD12);
    // nil for blur chains, blurred in place by deviations
    var filter: LayerTree.FilterLayer?
    var toDevice: CGAffineTransform = .identity
    // where the result is kept, when drawing with a cache
    var cacheKey: CGFilterLayerCache.Key?
    // what each feImage primitive draws, by primitive index
    var images: [Int: [RendererCommand<CGTypes>]] = [:]

    // user space to offscreen pixels: x right, y down from the first row in memory
    var pixelTransform: CGAffineTransform {
        let height = CGFloat(offscreen?.height ?? 0)
        return
            toDevice
            .concatenating(CGAffineTransform(translationX: -deviceRect.minX, y: -deviceRect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height))
    }

    // Draws the contents of an feImage into a bitmap of the offscreen's size through the same transform,
    // so its pixels line up with the offscreen's. Only rasterizes: what to draw, and where, comes resolved.
    func rasterize(
        _ contents: [RendererCommand<CGTypes>],
        isPixelated: Bool,
        colorSpace: CGColorSpace?,
        maxFilterLayerPixels: Int
    ) -> FilterBitmap? {
        guard let offscreen,
            let context = CGContext.makeFilterLayer(
                width: offscreen.width,
                height: offscreen.height,
                colorSpace: colorSpace
            ),
            let data = context.data
        else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -deviceRect.minX, y: -deviceRect.minY)
        context.concatenate(toDevice)
        context.interpolationQuality = isPixelated ? .none : .default
        CGRenderer(context: context, baseCTM: .identity, maxFilterLayerPixels: maxFilterLayerPixels).perform(contents)

        let width = context.width
        let height = context.height
        let rowBytes = width * 4
        var bitmap = FilterBitmap(width: width, height: height)
        bitmap.pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            for row in 0..<height {
                memcpy(base + row * rowBytes, data + row * context.bytesPerRow, rowBytes)
            }
        }
        return bitmap
    }

    // nil when the device rect is empty or not finite
    static func make(
        deviceRect: CGRect,
        deviations: [CGSize],
        maxPixels: Int,
        oversample: CGFloat,
        colorSpace: CGColorSpace?
    ) -> CGFilterLayer? {
        guard !deviceRect.isNull, !deviceRect.isInfinite,
            deviceRect.minX.isFinite, deviceRect.minY.isFinite,
            deviceRect.width.isFinite, deviceRect.height.isFinite
        else { return nil }
        let rect = deviceRect.integral
        guard rect.width >= 1, rect.height >= 1 else { return nil }

        let scale = makeScale(size: rect.size, maxPixels: maxPixels, oversample: oversample)
        let width = max(1, Int((rect.width * scale).rounded(.up)))
        let height = max(1, Int((rect.height * scale).rounded(.up)))
        guard let offscreen = CGContext.makeFilterLayer(width: width, height: height, colorSpace: colorSpace) else {
            return nil
        }

        offscreen.scaleBy(x: scale, y: scale)
        offscreen.translateBy(x: -rect.minX, y: -rect.minY)
        return CGFilterLayer(offscreen: offscreen, deviceRect: rect, deviations: deviations, scale: scale)
    }

    // largest scale ≤ oversample that keeps the bitmap within maxPixels and each side within maxSide
    static func makeScale(size: CGSize, maxPixels: Int, oversample: CGFloat) -> CGFloat {
        let maxSide = CGFloat(maxPixels).squareRoot() * 4
        let pixels = size.width * size.height
        var scale = oversample
        scale = min(scale, (CGFloat(maxPixels) / pixels).squareRoot())
        scale = min(scale, maxSide / size.width, maxSide / size.height)
        return scale
    }
}

private extension LayerTree.FilterLayer.Effect {

    // a blur that is not along the device axes
    func isSheared(_ toDevice: CGAffineTransform) -> Bool {
        guard case let .gaussianBlur(stdDeviation: x, stdDeviationY: y) = self else { return false }
        let matrix = LayerTree.Transform.Matrix(
            a: Float(toDevice.a),
            b: Float(toDevice.b),
            c: Float(toDevice.c),
            d: Float(toDevice.d),
            tx: 0,
            ty: 0
        )
        return matrix.blurShear(x, y) != nil
    }

    // stdDeviation converted to device pixels along the device axes; nil when it does not blur.
    // The extent of the blur along each axis: a sheared blur is not separable along them.
    func deviceStdDeviation(_ toDevice: CGAffineTransform) -> CGSize? {
        guard case let .gaussianBlur(stdDeviation: x, stdDeviationY: y) = self else { return nil }
        let sx = CGFloat(x)
        let sy = CGFloat(y)
        let width = hypot(sx * toDevice.a, sy * toDevice.c)
        let height = hypot(sx * toDevice.b, sy * toDevice.d)
        let size = CGSize(width: width.isFinite ? width : 0, height: height.isFinite ? height : 0)
        return size.width > 0 || size.height > 0 ? size : nil
    }
}

private extension LayerTree.FilterLayer {

    // How far the filter can move a pixel, in device pixels: three deviations per blur plus each offset.
    // Every path through the primitive tree is covered by the sum over all primitives.
    func deviceSpread(_ toDevice: CGAffineTransform) -> CGSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        for effect in effects {
            switch effect {
            case .gaussianBlur:
                if let deviation = effect.deviceStdDeviation(toDevice) {
                    width += 3 * deviation.width
                    height += 3 * deviation.height
                }
            case let .offset(dx: dx, dy: dy):
                let vector = CGSize(width: CGFloat(dx), height: CGFloat(dy)).applying(toDevice)
                width += abs(vector.width)
                height += abs(vector.height)
            case let .morphology(_, radiusX: rx, radiusY: ry):
                // erode and dilate both read pixels up to the radius away
                let x = CGSize(width: CGFloat(rx), height: 0).applying(toDevice)
                let y = CGSize(width: 0, height: CGFloat(ry)).applying(toDevice)
                width += abs(x.width) + abs(y.width)
                height += abs(x.height) + abs(y.height)
            case .convolveMatrix(let matrix):
                // the kernel reads pixels up to its size away; it is in pixels of the bitmap, at most the
                // oversample per device pixel
                width += CGFloat(matrix.orderX) * 2
                height += CGFloat(matrix.orderY) * 2
            case .flood, .composite, .merge, .blend, .colorMatrix, .componentTransfer, .turbulence, .image:
                break
            }
        }
        return CGSize(
            width: width.isFinite ? min(width, CGRenderer.maxDeviceSpread) : CGRenderer.maxDeviceSpread,
            height: height.isFinite ? min(height, CGRenderer.maxDeviceSpread) : CGRenderer.maxDeviceSpread
        )
    }
}

extension CGContext {

    /// Whether this is a bitmap context, found without calling CGBitmapContext functions: on a PDF,
    /// CGLayer or SwiftUI Canvas context those log "invalid context" (with a backtrace under Xcode).
    /// The context's description names its type, e.g. `<CGContext 0x…> (kCGContextTypeBitmap)`.
    /// If that ever changes, contexts are treated as vector, which only rasterizes offscreen layers at 2x.
    var isBitmapContext: Bool {
        (CFCopyDescription(self) as String).contains("(kCGContextTypeBitmap)")
    }

    static func makeFilterLayer(width: Int, height: Int, colorSpace: CGColorSpace?) -> CGContext? {
        let sRGB = CGColorSpace.sRGBSpace
        let space = colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? sRGB
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: info
        )
            ?? CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: sRGB,
                bitmapInfo: info
            )
    }

    // Filter Effects 1 §9.16 / SVG 1.1 §15.17: three successive box blurs approximate the gaussian.
    // Box sizes must be odd for vImage, so an even size d becomes d+1, d-1, d+1 (near-identical variance).
    func applyGaussianBlur(_ deviation: CGSize) {
        guard let data else { return }
        Self.applyGaussianBlur(deviation, data: data, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    static func applyGaussianBlur(
        _ deviation: CGSize,
        data: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) {
        // Each pass treats pixels outside the bitmap as transparent. A box of 2n-1 then covers a whole row
        // (or column) of n from every pixel, so a wider box only divides that sum by more: clamp per axis
        // and scale the result by what the clamp left out, exactly as the wider box would.
        guard width > 0, height > 0 else { return }
        let requestedX = Self.boxSizes(for: deviation.width)
        let requestedY = Self.boxSizes(for: deviation.height)
        let sizesX = requestedX.map { Swift.min($0, 2 * width - 1) }
        let sizesY = requestedY.map { Swift.min($0, 2 * height - 1) }
        guard requestedX.contains(where: { $0 > 1 }) || requestedY.contains(where: { $0 > 1 }) else { return }
        var scale: Double = 1
        for (size, requested) in zip(sizesX + sizesY, requestedX + requestedY) where size < requested {
            scale *= Double(size) / Double(requested)
        }

        let byteCount = bytesPerRow * height
        guard let temp = calloc(byteCount, 1) else { return }
        defer { free(temp) }

        var src = vImage_Buffer(
            data: data,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )
        var dst = vImage_Buffer(
            data: temp,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )
        var background: [UInt8] = [0, 0, 0, 0]
        for pass in 0..<3 {
            let error = vImageBoxConvolve_ARGB8888(
                &src,
                &dst,
                nil,
                0,
                0,
                UInt32(sizesY[pass]),
                UInt32(sizesX[pass]),
                &background,
                vImage_Flags(kvImageBackgroundColorFill)
            )
            guard error == kvImageNoError else { return }
            swap(&src, &dst)
        }
        // after three passes the result is in the temporary buffer
        memcpy(data, src.data, byteCount)
        if scale < 1 {
            let bytes = data.assumingMemoryBound(to: UInt8.self)
            for row in 0..<height {
                let start = row * bytesPerRow
                for i in start..<(start + width * 4) {
                    bytes[i] = UInt8((Double(bytes[i]) * scale).rounded())
                }
            }
        }
    }

    // SD12: evaluates the primitive tree on the offscreen's pixels, SourceGraphic being what was drawn,
    // and leaves the result in their place.
    func applyFilter(
        _ filter: LayerTree.FilterLayer,
        toPixels transform: CGAffineTransform,
        image: @escaping (Int) -> FilterBitmap? = { _ in nil }
    ) {
        let width = width
        let height = height
        let bytesPerRow = bytesPerRow
        let colorSpace = colorSpace
        guard let data = data, width > 0, height > 0 else { return }
        let rowBytes = width * 4

        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            for row in 0..<height {
                memcpy(base + row * rowBytes, data + row * bytesPerRow, rowBytes)
            }
        }

        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(
                a: Float(transform.a),
                b: Float(transform.b),
                c: Float(transform.c),
                d: Float(transform.d),
                tx: Float(transform.tx),
                ty: Float(transform.ty)
            ),
            blur: { bitmap, x, y in
                let w = bitmap.width
                let h = bitmap.height
                bitmap.pixels.withUnsafeMutableBytes { buffer in
                    guard let base = buffer.baseAddress else { return }
                    CGContext.applyGaussianBlur(
                        CGSize(width: CGFloat(x), height: CGFloat(y)),
                        data: base,
                        width: w,
                        height: h,
                        bytesPerRow: w * 4
                    )
                }
            },
            color: { CGContext.filterComponents(of: $0, colorSpace: colorSpace) },
            image: image
        )
        let result = filter.evaluate(
            source: FilterBitmap(width: width, height: height, pixels: pixels),
            environment: environment
        )

        result.pixels.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            for row in 0..<height {
                memcpy(data + row * bytesPerRow, base + row * rowBytes, rowBytes)
            }
        }
    }

    // The straight RGBA a fill of this colour leaves in a filter layer of the colour space:
    // floods are colour matched exactly like the shapes they are composited with.
    static func filterComponents(of color: LayerTree.Color, colorSpace: CGColorSpace?) -> SIMD4<Float> {
        guard let ctx = CGContext.makeFilterLayer(width: 1, height: 1, colorSpace: colorSpace),
            let data = ctx.data
        else {
            return FilterBitmap.components(of: color)
        }
        ctx.setFillColor(CGProvider().createColor(from: color))
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let pixel = data.assumingMemoryBound(to: UInt8.self)
        let alpha = Float(pixel[3])
        guard alpha > 0 else { return .zero }
        return SIMD4(Float(pixel[0]) / alpha, Float(pixel[1]) / alpha, Float(pixel[2]) / alpha, alpha / 255)
    }

    static func isVisibleBlur(_ deviation: CGSize, scale: CGFloat) -> Bool {
        boxSizes(for: deviation.width * scale) != [1, 1, 1] || boxSizes(for: deviation.height * scale) != [1, 1, 1]
    }

    static func boxSizes(for deviation: CGFloat) -> [Int] {
        guard deviation.isFinite, deviation > 0 else { return [1, 1, 1] }
        let factor: CGFloat = 3 * (2 * CGFloat.pi).squareRoot() / 4
        let value = Swift.min(deviation * factor + 0.5, CGFloat(1 << 24))
        let d = Int(value.rounded(.down))
        guard d > 1 else { return [1, 1, 1] }
        return d % 2 == 1 ? [d, d, d] : [d + 1, d - 1, d + 1]
    }
}

#endif
