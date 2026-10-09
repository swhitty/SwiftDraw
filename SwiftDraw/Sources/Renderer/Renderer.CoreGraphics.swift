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
        let renderer = CGRenderer(context: ctx)
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
        return CGRect(x: CGFloat(rect.x),
                      y: CGFloat(rect.y),
                      width: CGFloat(rect.width),
                      height: CGFloat(rect.height))
    }

    func createColor(from color: LayerTree.Color) -> CGColor {
        switch color {
        case .none: return createSRGB(r: 0, g: 0, b: 0, a: 0)
        case let .rgba(r, g, b, a, .srgb):
            return createSRGB(r: CGFloat(r),
                              g: CGFloat(g),
                              b: CGFloat(b),
                              a: CGFloat(a))
        case let .rgba(r, g, b, a, .p3):
            return createP3(r: CGFloat(r),
                            g: CGFloat(g),
                            b: CGFloat(b),
                            a: CGFloat(a))
        case .gray(white: let w, a: let a):
            return createColor(w: CGFloat(w), a: CGFloat(a))
        }
    }

    private func createColorSpace(for colorSpace: LayerTree.ColorSpace) -> CGColorSpace {
        switch colorSpace {
        case .srgb:
            return CGColorSpaceCreateDeviceRGB()
        case .p3:
            return CGColorSpace(name: CGColorSpace.displayP3)!
        }
    }

    func createGradient(from gradient: LayerTree.Gradient) -> CGGradient {
        let colors = gradient.stops.map { createColor(from: $0.color) } as CFArray
        var points = gradient.stops.map { createFloat(from: $0.offset) }

        return CGGradient(colorsSpace: createColorSpace(for: gradient.colorSpace),
                          colors: colors,
                          locations: &points)!
    }

    private func createSRGB(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                       components: [r, g, b, a])!
    }

    private func createP3(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
                       components: [r, g, b, a])!
    }

    private func createColor(w: CGFloat, a: CGFloat) -> CGColor {
        return CGColor(colorSpace: CGColorSpaceCreateExtendedGray(),
                       components: [w, a])!
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
        return CGAffineTransform(a: CGFloat(transform.a),
                                 b: CGFloat(transform.b),
                                 c: CGFloat(transform.c),
                                 d: CGFloat(transform.d),
                                 tx: CGFloat(transform.tx),
                                 ty: CGFloat(transform.ty))
    }

    func createPath(from shape: LayerTree.Shape) -> CGPath {
        switch shape {
        case .line(let points):
            let path = CGMutablePath()
            path.addLines(between: points.map{ createPoint(from: $0) })
            return path
        case .rect(let frame, let radii):
            return CGPath(roundedRect: createRect(from: frame),
                          cornerWidth: createFloat(from: radii.width),
                          cornerHeight: createFloat(from: radii.height),
                          transform: nil)
        case .ellipse(let frame):
            return CGPath(ellipseIn: createRect(from: frame), transform: nil)
        case .polygon(let points):
            let path = CGMutablePath()
            path.addLines(between: points.map{ createPoint(from: $0) })
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
                cgPath.addCurve(to: createPoint(from: p),
                                control1: createPoint(from: cp1),
                                control2: createPoint(from: cp2))
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

    func createPath(from text: String, at origin: LayerTree.Point, with attributes: LayerTree.TextAttributes) -> Types.Path? {
        let font = CGProvider.createCTFont(for: attributes.font, size: attributes.size)
        guard let path = text.toPath(font: font) else { return nil }
        var transform = CGAffineTransform(translationX: createFloat(from: origin.x), y: createFloat(from: origin.y))
        return path.copy(using: &transform)
    }

    private static func createCTFont(for font: LayerTree.TextAttributes.Font, size: CGFloat) -> CTFont? {
        switch font {
        case .truetype(let data):
            guard let provider = CGDataProvider(data: data as CFData),
                  let cgFont = CGFont(provider) else { return nil }
            return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        case .name(let name):
            let ctFont = CTFontCreateWithName(name as CFString, size, nil)
            let postScriptName = CTFontCopyPostScriptName(ctFont) as String
            if postScriptName.caseInsensitiveCompare(name) == .orderedSame
                || CTFontCopyFamilyName(ctFont) as String == name {
                return ctFont
            }
            return nil
        }
    }

    static func createCTFont(for fonts: [LayerTree.TextAttributes.Font], size: Float) -> CTFont {
        let cgSize = CGFloat(size)
        let fallback = CTFontCreateWithName("Times" as CFString, cgSize, nil)
        let ctFonts = fonts.compactMap { createCTFont(for: $0, size: cgSize) }
        guard let primary = ctFonts.first else { return fallback }
        guard ctFonts.count > 1 else { return primary }
        let descriptors = ctFonts.dropFirst().map { CTFontCopyFontDescriptor($0) }
        let cascade = CTFontDescriptorCreateWithAttributes(
            [kCTFontCascadeListAttribute: descriptors] as CFDictionary
        )
        return CTFontCreateCopyWithAttributes(primary, cgSize, nil, cascade)
    }

    func createPattern(from pattern: LayerTree.Pattern, contents: [RendererCommand<Types>]) -> CGTransformingPattern {
        let bounds = createRect(from: pattern.frame)
        return CGTransformingPattern(bounds: bounds,
                                     contents: contents,
                                     transform: createTransform(from: pattern.transform))
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
        return LayerTree.Rect(x: LayerTree.Float(bounds.origin.x),
                              y: LayerTree.Float(bounds.origin.y),
                              width: LayerTree.Float(bounds.width),
                              height: LayerTree.Float(bounds.height))
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

    // drawing goes into the innermost offscreen filter layer, if any
    var ctx: CGContext { filterLayers.context ?? rootContext }

    // offscreen filter layers are bitmaps whose base space is the identity
    var baseCTM: CGAffineTransform { filterLayers.context == nil ? rootCTM : .identity }

    init(context: CGContext, maxFilterLayerPixels: Int = CGRenderer.defaultMaxFilterLayerPixels) {
        self.rootContext = context
        self.rootCTM = context.ctm
        self.maxFilterLayerPixels = maxFilterLayerPixels
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
        var alpha : CGFloat = 1.0

        let cgPattern = CGPattern.make(bounds: pattern.bounds,
                                       matrix: pattern.transform.concatenating(ctx.ctm.concatenating(baseCTM.inverted())),
                                       step: pattern.bounds.size,
                                       tiling: .constantSpacingMinimalDistortion,
                                       isColored: true,
                                       draw: pattern.draw)
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
        ctx.drawLinearGradient(gradient,
                               start: start,
                               end: end,
                               options: [.drawsAfterEndLocation, .drawsBeforeStartLocation]
        )
    }

    func draw(radial gradient: CGGradient, startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat) {
        ctx.drawRadialGradient(gradient,
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
        let region = CGRect(x: CGFloat(filter.region.x),
                            y: CGFloat(filter.region.y),
                            width: CGFloat(filter.region.width),
                            height: CGFloat(filter.region.height))
        let toDevice = parent.userSpaceToDeviceSpaceTransform
        let isBlurChain = filter.isBlurChain
        let deviations = isBlurChain ? filter.effects.compactMap { $0.deviceStdDeviation(toDevice) } : []
        let visible = parent.boundingBoxOfClipPath

        parent.saveGState()
        parent.clip(to: region)

        // empty clip: draw nothing and allocate nothing
        guard !visible.isNull, !visible.isEmpty else {
            parent.clip(to: .zero)
            filterLayers.entries.append(CGFilterLayer())
            return
        }

        // blurs too small to change a pixel (every box size 1) are a pass-through:
        // draw straight into the parent, clipped to the region
        let isVector = parent.bitsPerPixel == 0
        let oversample: CGFloat = isVector ? 2 : 1
        if isBlurChain && !deviations.contains(where: { CGContext.isVisibleBlur($0, scale: oversample) }) {
            filterLayers.entries.append(CGFilterLayer())
            return
        }

        var deviceRect = region.applying(toDevice)
        if !visible.isInfinite {
            let spread = filter.deviceSpread(toDevice)
            deviceRect = deviceRect.intersection(visible.applying(toDevice).insetBy(dx: -spread.width, dy: -spread.height))
        }

        // the offscreen itself, plus the bitmaps of the primitive tree
        let maxPixels = isBlurChain ? maxFilterLayerPixels : maxFilterLayerPixels / (filter.peakBitmapCount + 1)

        // PDF and other vector contexts: filtered groups are rasterized at 2x (2 px per point)
        guard var layer = CGFilterLayer.make(deviceRect: deviceRect,
                                             deviations: deviations,
                                             maxPixels: maxPixels,
                                             oversample: oversample,
                                             colorSpace: parent.colorSpace) else {
            // empty clip or region: draw nothing and allocate nothing
            parent.clip(to: .zero)
            filterLayers.entries.append(CGFilterLayer())
            return
        }
        if !isBlurChain {
            layer.filter = filter
            layer.toDevice = toDevice
        }

        layer.offscreen?.concatenate(toDevice)
        // input outside the region is excluded (it matters under rotation or skew); the edge is anti-aliased
        // once, by the parent clip at composite time
        layer.offscreen?.setShouldAntialias(false)
        layer.offscreen?.clip(to: region)
        layer.offscreen?.setShouldAntialias(true)
        filterLayers.entries.append(layer)
    }

    func popFilterLayer() {
        guard let layer = filterLayers.entries.popLast() else { return }
        let parent = ctx

        if let offscreen = layer.offscreen {
            if let filter = layer.filter {
                offscreen.applyFilter(filter, toPixels: layer.pixelTransform)
            } else {
                for deviation in layer.deviations {
                    offscreen.applyGaussianBlur(CGSize(width: deviation.width * layer.scale,
                                                       height: deviation.height * layer.scale))
                }
            }
            if let image = offscreen.makeImage() {
                let size = CGSize(width: CGFloat(image.width) / layer.scale,
                                  height: CGFloat(image.height) / layer.scale)
                parent.saveGState()
                parent.concatenate(parent.userSpaceToDeviceSpaceTransform.inverted())
                if layer.scale == 1 {
                    parent.interpolationQuality = .none
                }
                parent.draw(image, in: CGRect(origin: layer.deviceRect.origin, size: size))
                parent.restoreGState()
            }
        }

        // removes the region clip set by pushFilterLayer
        parent.restoreGState()
    }

    static let defaultMaxFilterLayerPixels = 16_777_216
    static let maxDeviceSpread: CGFloat = 100_000
}

final class CGFilterLayerStack {
    var entries = [CGFilterLayer]()

    var context: CGContext? {
        entries.last(where: { $0.offscreen != nil })?.offscreen
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

    // user space to offscreen pixels: x right, y down from the first row in memory
    var pixelTransform: CGAffineTransform {
        let height = CGFloat(offscreen?.height ?? 0)
        return toDevice
            .concatenating(CGAffineTransform(translationX: -deviceRect.minX, y: -deviceRect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height))
    }

    // nil when the device rect is empty or not finite
    static func make(deviceRect: CGRect,
                     deviations: [CGSize],
                     maxPixels: Int,
                     oversample: CGFloat,
                     colorSpace: CGColorSpace?) -> CGFilterLayer? {
        guard !deviceRect.isNull, !deviceRect.isInfinite,
              deviceRect.minX.isFinite, deviceRect.minY.isFinite,
              deviceRect.width.isFinite, deviceRect.height.isFinite else { return nil }
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

    // stdDeviation converted to device pixels along the device axes; nil when it does not blur.
    // Exact for scale and 90° rotations, an approximation under skew or other rotations.
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
            case .flood, .composite, .merge, .blend, .colorMatrix:
                break
            }
        }
        return CGSize(width: width.isFinite ? min(width, CGRenderer.maxDeviceSpread) : CGRenderer.maxDeviceSpread,
                      height: height.isFinite ? min(height, CGRenderer.maxDeviceSpread) : CGRenderer.maxDeviceSpread)
    }
}

extension CGContext {

    static func makeFilterLayer(width: Int, height: Int, colorSpace: CGColorSpace?) -> CGContext? {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let space = colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? sRGB
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info) ??
               CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB, bitmapInfo: info)
    }

    // Filter Effects 1 §9.16 / SVG 1.1 §15.17: three successive box blurs approximate the gaussian.
    // Box sizes must be odd for vImage, so an even size d becomes d+1, d-1, d+1 (near-identical variance).
    func applyGaussianBlur(_ deviation: CGSize) {
        guard let data else { return }
        Self.applyGaussianBlur(deviation, data: data, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    static func applyGaussianBlur(_ deviation: CGSize, data: UnsafeMutableRawPointer, width: Int, height: Int, bytesPerRow: Int) {
        // a box wider than the image only spreads it further towards transparent: clamp per axis
        let sizesX = Self.boxSizes(for: deviation.width, limit: width | 1)
        let sizesY = Self.boxSizes(for: deviation.height, limit: height | 1)
        guard sizesX.contains(where: { $0 > 1 }) || sizesY.contains(where: { $0 > 1 }) else { return }

        let byteCount = bytesPerRow * height
        guard let temp = calloc(byteCount, 1) else { return }
        defer { free(temp) }

        var src = vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        var dst = vImage_Buffer(data: temp, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        var background: [UInt8] = [0, 0, 0, 0]
        for pass in 0..<3 {
            let error = vImageBoxConvolve_ARGB8888(&src, &dst, nil, 0, 0,
                                                   UInt32(sizesY[pass]), UInt32(sizesX[pass]),
                                                   &background, vImage_Flags(kvImageBackgroundColorFill))
            guard error == kvImageNoError else { return }
            swap(&src, &dst)
        }
        // after three passes the result is in the temporary buffer
        memcpy(data, src.data, byteCount)
    }

    // SD12: evaluates the primitive tree on the offscreen's pixels, SourceGraphic being what was drawn,
    // and leaves the result in their place.
    func applyFilter(_ filter: LayerTree.FilterLayer, toPixels transform: CGAffineTransform) {
        let width = self.width
        let height = self.height
        let bytesPerRow = self.bytesPerRow
        let colorSpace = self.colorSpace
        guard let data = self.data, width > 0, height > 0 else { return }
        let rowBytes = width * 4

        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            for row in 0..<height {
                memcpy(base + row * rowBytes, data + row * bytesPerRow, rowBytes)
            }
        }

        let environment = LayerTree.FilterLayer.Environment(
            transform: LayerTree.Transform.Matrix(a: Float(transform.a), b: Float(transform.b),
                                                  c: Float(transform.c), d: Float(transform.d),
                                                  tx: Float(transform.tx), ty: Float(transform.ty)),
            blur: { bitmap, x, y in
                let w = bitmap.width
                let h = bitmap.height
                bitmap.pixels.withUnsafeMutableBytes { buffer in
                    guard let base = buffer.baseAddress else { return }
                    CGContext.applyGaussianBlur(CGSize(width: CGFloat(x), height: CGFloat(y)),
                                                data: base, width: w, height: h, bytesPerRow: w * 4)
                }
            },
            color: { CGContext.filterComponents(of: $0, colorSpace: colorSpace) }
        )
        let result = filter.evaluate(source: FilterBitmap(width: width, height: height, pixels: pixels),
                                     environment: environment)

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
              let data = ctx.data else {
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

    // limit is odd: the largest box size worth applying
    static func boxSizes(for deviation: CGFloat, limit: Int = .max) -> [Int] {
        guard deviation.isFinite, deviation > 0 else { return [1, 1, 1] }
        let factor: CGFloat = 3 * (2 * CGFloat.pi).squareRoot() / 4
        let value = Swift.min(deviation * factor + 0.5, CGFloat(Swift.min(limit, 1 << 24)))
        let d = Int(value.rounded(.down))
        guard d > 1 else { return [1, 1, 1] }
        return d % 2 == 1 ? [d, d, d] : [d + 1, d - 1, d + 1]
    }
}

#endif
