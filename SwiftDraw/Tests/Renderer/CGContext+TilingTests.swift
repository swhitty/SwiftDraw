//
//  CGContext+TilingTests.swift
//  SwiftDraw
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//

#if canImport(CoreGraphics)
import CoreGraphics
import Testing
@testable import SwiftDraw

struct CGContextTilingTests {

    @Test
    func allTilesWhenFullyVisible() {
        let rect = CGRect(x: 0, y: 0, width: 25, height: 20)
        let tiles = CGContext.tiles(of: CGSize(width: 10, height: 10), in: rect, visible: rect)
        #expect(tiles.count == 6)
        #expect(tiles.first == CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(tiles.last == CGRect(x: 20, y: 10, width: 10, height: 10))
    }

    @Test
    func onlyTilesIntersectingVisibleRect() {
        let rect = CGRect(x: 0, y: 0, width: 10_000, height: 10_000)
        let visible = CGRect(x: 15, y: 5, width: 10, height: 10)
        let tiles = CGContext.tiles(of: CGSize(width: 10, height: 10), in: rect, visible: visible)
        #expect(
            tiles == [
                CGRect(x: 10, y: 0, width: 10, height: 10),
                CGRect(x: 20, y: 0, width: 10, height: 10),
                CGRect(x: 10, y: 10, width: 10, height: 10),
                CGRect(x: 20, y: 10, width: 10, height: 10),
            ]
        )
    }

    @Test(arguments: [false, true])
    func cachedTilesMatchVectorTiles(flipped: Bool) throws {
        let svg = try #require(SVG(xml: Self.asymmetric))
        let rect = CGRect(x: 3, y: 2, width: 50, height: 37)

        let cached = try Self.render(scale: 2, flipped: flipped) {
            $0.draw(svg, in: rect, byTiling: true)
        }
        let vector = try Self.render(scale: 2, flipped: flipped) { ctx in
            ctx.clip(to: CGRect(x: 3, y: 2, width: 60, height: 40))
            for tile in CGContext.tiles(of: svg.size, in: rect, visible: rect) {
                ctx.draw(svg, in: tile)
            }
        }
        #expect(Self.maxDifference(cached, vector) <= 2)
    }

    @Test(arguments: [false, true])
    func cachedSlicesMatchVectorSlices(flipped: Bool) throws {
        let svg = try #require(SVG(xml: Self.asymmetric))
        let rect = CGRect(x: 0, y: 0, width: 64, height: 48)
        let insets: (CGFloat, CGFloat, CGFloat, CGFloat) = (2, 2, 4, 4)

        let cached = try Self.render(scale: 2, flipped: flipped) {
            $0.draw(svg, in: rect, capInsets: insets, byTiling: true)
        }
        // a scale of 0 makes no tile image, so every tile is drawn as vectors
        let vector = try Self.render(scale: 2, flipped: flipped) {
            $0.draw(svg, in: rect, capInsets: insets, byTiling: true, tileScale: 0)
        }
        #expect(Self.maxDifference(cached, vector) <= 2)
    }

    @Test
    func tileImageIsCappedInSize() throws {
        let svg = try #require(SVG(xml: Self.asymmetric))
        let ctx = try Self.makeContext(width: 1, height: 1)
        let source = CGRect(origin: .zero, size: svg.size)
        #expect(ctx.makeTileImage(svg, from: source, scale: 2) != nil)
        #expect(ctx.makeTileImage(svg, from: source, scale: 10_000) == nil)
    }

    // red top-left quarter, blue along the bottom: wrong in any flip or mirror
    static let asymmetric = """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="8">
          <rect width="5" height="4" fill="red"/>
          <rect y="6" width="10" height="2" fill="blue"/>
          <circle cx="7" cy="3" r="2" fill="green"/>
        </svg>
        """

    static func makeContext(width: Int, height: Int) throws -> CGContext {
        try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
    }

    static func render(scale: CGFloat, flipped: Bool, _ draw: (CGContext) -> Void) throws -> [UInt8] {
        let width = 64 * Int(scale), height = 48 * Int(scale)
        let ctx = try makeContext(width: width, height: height)
        if flipped {
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
        }
        ctx.scaleBy(x: scale, y: scale)
        draw(ctx)
        let data = try #require(ctx.data)
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
    }

    static func maxDifference(_ a: [UInt8], _ b: [UInt8]) -> Int {
        zip(a, b).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }
}
#endif
