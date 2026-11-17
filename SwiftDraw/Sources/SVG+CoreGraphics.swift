//
//  SVG+CoreGraphics.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/5/17.
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
public import CoreGraphics
public import Foundation

public extension CGContext {

    func draw(_ svg: SVG, in rect: CGRect? = nil) {
        draw(svg, in: rect, baseCTM: nil)
    }
}

extension CGContext {

    /// `baseCTM` is the context's default space (see `CGRenderer`); nil uses the current CTM.
    /// `filters` keeps filtered results between draws of the same SVG, e.g. by a view.
    func draw(_ svg: SVG, in rect: CGRect?, baseCTM: CGAffineTransform?, filters: CGFilterLayerDraw? = nil) {
        let defaultRect = CGRect(x: 0, y: 0, width: svg.size.width, height: svg.size.height)
        filters?.cache.prepare(for: svg, size: rect?.size ?? svg.size)
        let renderer = CGRenderer(context: self, baseCTM: baseCTM, filters: filters)
        saveGState()

        if let rect = rect, rect != defaultRect {
            translateBy(x: rect.origin.x, y: rect.origin.y)
            scaleBy(
                x: rect.width / svg.size.width,
                y: rect.height / svg.size.height
            )
        }
        renderer.perform(svg.commands)

        restoreGState()
    }
}

public extension CGContext {

    func draw(_ svg: SVG, in rect: CGRect, byTiling: Bool) {
        draw(svg, in: rect, byTiling: byTiling, tileScale: nil)
    }

    func draw(
        _ svg: SVG,
        in rect: CGRect,
        capInsets: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat),
        byTiling: Bool
    ) {
        draw(svg, in: rect, capInsets: capInsets, byTiling: byTiling, tileScale: nil)
    }
}

extension CGContext {

    /// `tileScale` is the device pixels per point to rasterize a tile at; nil reads it from the CTM.
    func draw(_ svg: SVG, in rect: CGRect, byTiling: Bool, tileScale: CGFloat?, filters: CGFilterLayerDraw? = nil) {
        guard byTiling else {
            draw(svg, in: rect, baseCTM: nil, filters: filters)
            return
        }
        filters?.cache.prepare(for: svg, size: rect.size)
        let size = svg.size
        guard size.width > 0, size.height > 0 else { return }

        // whole tiles from rect's origin, the last row and column may overhang rect
        let grid = CGRect(
            origin: rect.origin,
            size: CGSize(
                width: ceil(rect.width / size.width) * size.width,
                height: ceil(rect.height / size.height) * size.height
            )
        )
        saveGState()
        clip(to: grid)
        drawTiles(svg, from: CGRect(origin: .zero, size: size), in: grid, tileScale: tileScale, filters: filters)
        restoreGState()
    }

    func draw(
        _ svg: SVG,
        in rect: CGRect,
        capInsets: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat),
        byTiling: Bool,
        tileScale: CGFloat?,
        filters: CGFilterLayerDraw? = nil
    ) {
        guard capInsets != (0, 0, 0, 0) else {
            draw(svg, in: rect, byTiling: byTiling, tileScale: tileScale, filters: filters)
            return
        }
        filters?.cache.prepare(for: svg, size: rect.size)

        let source = Slice9(source: CGRect(origin: .zero, size: svg.size), capInsets: capInsets)
        let dest = Slice9(source: rect, capInsets: capInsets)

        draw(svg, from: source.topLeft, in: dest.topLeft, byTiling: false, tileScale: tileScale, filters: filters)
        draw(svg, from: source.topMid, in: dest.topMid, byTiling: byTiling, tileScale: tileScale, filters: filters)
        draw(svg, from: source.topRight, in: dest.topRight, byTiling: false, tileScale: tileScale, filters: filters)
        draw(svg, from: source.midLeft, in: dest.midLeft, byTiling: byTiling, tileScale: tileScale, filters: filters)
        draw(svg, from: source.center, in: dest.center, byTiling: byTiling, tileScale: tileScale, filters: filters)
        draw(svg, from: source.midRight, in: dest.midRight, byTiling: byTiling, tileScale: tileScale, filters: filters)
        draw(svg, from: source.bottomLeft, in: dest.bottomLeft, byTiling: false, tileScale: tileScale, filters: filters)
        draw(
            svg,
            from: source.bottomMid,
            in: dest.bottomMid,
            byTiling: byTiling,
            tileScale: tileScale,
            filters: filters
        )
        draw(
            svg,
            from: source.bottomRight,
            in: dest.bottomRight,
            byTiling: false,
            tileScale: tileScale,
            filters: filters
        )
    }

    private func draw(
        _ svg: SVG,
        from source: CGRect,
        in rect: CGRect,
        byTiling: Bool,
        tileScale: CGFloat?,
        filters: CGFilterLayerDraw?
    ) {
        saveGState()
        clip(to: [rect])
        if byTiling {
            drawTiles(svg, from: source, in: rect, tileScale: tileScale, filters: filters)
        } else {
            drawStretched(svg, from: source, in: rect, filters: filters)
        }
        restoreGState()
    }

    // draws source of svg at its own size, repeated from rect's origin across the clip.
    // Rendering the SVG (filters included) once per tile can take seconds for a small SVG tiled across
    // a window, so a single tile is rasterized at device scale and CoreGraphics repeats the image.
    // PDF keeps vector tiles; any tile count of 1 or less renders directly.
    private func drawTiles(
        _ svg: SVG,
        from source: CGRect,
        in rect: CGRect,
        tileScale: CGFloat?,
        filters: CGFilterLayerDraw?
    ) {
        guard source.width > 0, source.height > 0 else { return }
        let visible = rect.intersection(boundingBoxOfClipPath)
        guard !visible.isNull, !visible.isEmpty else { return }
        let tiles = Self.tiles(of: source.size, in: rect, visible: visible)

        if tiles.count > 1, !isPDFContext,
            let image = makeTileImage(svg, from: source, scale: tileScale ?? deviceScale, filters: filters)
        {
            draw(image, in: CGRect(origin: rect.origin, size: source.size), byTiling: true)
            return
        }
        for tile in tiles {
            saveGState()
            clip(to: tile)
            drawStretched(svg, from: source, in: tile, filters: filters)
            restoreGState()
        }
    }

    private func drawStretched(_ svg: SVG, from source: CGRect, in rect: CGRect, filters: CGFilterLayerDraw?) {
        translateBy(x: rect.origin.x, y: rect.origin.y)
        scaleBy(
            x: rect.width / source.width,
            y: rect.height / source.height
        )
        translateBy(x: -source.minX, y: -source.minY)
        CGRenderer(context: self, filters: filters).perform(svg.commands)
    }

    // source of svg rasterized at scale pixels per point. Drawn with draw(_:in:) the image lands
    // exactly where the vector drawing would, whichever way the context is flipped.
    func makeTileImage(_ svg: SVG, from source: CGRect, scale: CGFloat, filters: CGFilterLayerDraw? = nil) -> CGImage? {
        let width = Int(ceil(source.width * scale))
        let height = Int(ceil(source.height * scale))
        guard width > 0, height > 0, width * height <= Self.maxTilePixels,
            let bitmap = CGContext.makeFilterLayer(
                width: width,
                height: height,
                colorSpace: isBitmapContext ? colorSpace : nil
            )
        else {
            return nil
        }
        bitmap.scaleBy(x: CGFloat(width) / source.width, y: CGFloat(height) / source.height)
        bitmap.translateBy(x: -source.minX, y: -source.minY)
        CGRenderer(context: bitmap, filters: filters).perform(svg.commands)
        return bitmap.makeImage()
    }

    static let maxTilePixels = 4096 * 4096

    // device pixels per point along the larger axis, at least 1
    var deviceScale: CGFloat {
        let t = userSpaceToDeviceSpaceTransform
        return max(1, hypot(t.a, t.b), hypot(t.c, t.d))
    }

    var isPDFContext: Bool {
        (CFCopyDescription(self) as String).contains("(kCGContextTypePDF)")
    }

    // tiles of size laid out from rect's origin, limited to those intersecting visible
    static func tiles(of size: CGSize, in rect: CGRect, visible: CGRect) -> [CGRect] {
        let cols = Int(ceil(rect.width / size.width))
        let rows = Int(ceil(rect.height / size.height))
        let c0 = max(0, Int(floor((visible.minX - rect.minX) / size.width)))
        let c1 = min(cols, Int(ceil((visible.maxX - rect.minX) / size.width)))
        let r0 = max(0, Int(floor((visible.minY - rect.minY) / size.height)))
        let r1 = min(rows, Int(ceil((visible.maxY - rect.minY) / size.height)))
        guard c0 < c1, r0 < r1 else { return [] }
        var tiles = [CGRect]()
        tiles.reserveCapacity((c1 - c0) * (r1 - r0))
        for r in r0..<r1 {
            for c in c0..<c1 {
                tiles.append(
                    CGRect(
                        x: rect.minX + CGFloat(c) * size.width,
                        y: rect.minY + CGFloat(r) * size.height,
                        width: size.width,
                        height: size.height
                    )
                )
            }
        }
        return tiles
    }
}

public extension SVG {

    func pdfData() throws -> Data {
        let (bounds, pixelsWide, pixelsHigh) = Self.makeBounds(size: size, scale: 1)
        var mediaBox = CGRect(x: 0.0, y: 0.0, width: CGFloat(pixelsWide), height: CGFloat(pixelsHigh))

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
            let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw Error("Failed to create CGContext")
        }

        ctx.beginPage(mediaBox: &mediaBox)
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: mediaBox.size.height)
        ctx.concatenate(flip)
        ctx.draw(self, in: bounds)
        ctx.endPage()
        ctx.closePDF()

        return data as Data
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}

extension SVG {

    static func makeBounds(size: CGSize, scale: CGFloat) -> (bounds: CGRect, pixelsWide: Int, pixelsHigh: Int) {
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: size.width * scale,
            height: size.height * scale
        )

        return (
            bounds: bounds,
            pixelsWide: Int(exactly: ceil(bounds.width)) ?? 0,
            pixelsHigh: Int(exactly: ceil(bounds.height)) ?? 0
        )
    }
}

private extension SVG.Insets {
    func applying(sx: CGFloat, sy: CGFloat) -> Self {
        Self(
            top: top * sy,
            left: left * sx,
            bottom: bottom * sy,
            right: right * sx
        )
    }
}

private extension LayerTree.Size {
    init(_ size: CGSize) {
        self.width = LayerTree.Float(size.width)
        self.height = LayerTree.Float(size.height)
    }
}

struct Slice9 {
    var source: CGRect
    var capInsets: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat)

    var topLeft: CGRect {
        CGRect(x: source.minX, y: source.minY, width: capInsets.left, height: capInsets.top)
    }

    var bottomLeft: CGRect {
        CGRect(x: source.minX, y: source.height - capInsets.bottom, width: capInsets.left, height: capInsets.bottom)
    }

    var topRight: CGRect {
        CGRect(x: source.maxX - capInsets.right, y: source.minY, width: capInsets.right, height: capInsets.top)
    }

    var bottomRight: CGRect {
        CGRect(
            x: source.maxX - capInsets.right,
            y: source.maxY - capInsets.bottom,
            width: capInsets.right,
            height: capInsets.bottom
        )
    }

    var midLeft: CGRect {
        CGRect(
            x: source.minX,
            y: capInsets.top,
            width: capInsets.left,
            height: source.maxY - capInsets.top - capInsets.bottom
        )
    }

    var midRight: CGRect {
        CGRect(
            x: source.maxX - capInsets.right,
            y: capInsets.top,
            width: capInsets.right,
            height: source.maxY - capInsets.top - capInsets.bottom
        )
    }

    var topMid: CGRect {
        CGRect(
            x: capInsets.left,
            y: source.minY,
            width: source.maxX - capInsets.left - capInsets.right,
            height: capInsets.top
        )
    }

    var bottomMid: CGRect {
        CGRect(
            x: capInsets.left,
            y: source.maxY - capInsets.bottom,
            width: source.maxX - capInsets.left - capInsets.right,
            height: capInsets.bottom
        )
    }

    var center: CGRect {
        CGRect(
            x: capInsets.left,
            y: capInsets.top,
            width: source.maxX - capInsets.left - capInsets.right,
            height: source.maxY - capInsets.top - capInsets.bottom
        )
    }
}

#endif
