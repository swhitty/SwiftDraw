//
//  CGFilterLayerCacheTests.swift
//  SwiftDraw
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import Testing
@testable import SwiftDraw

struct CGFilterLayerCacheTests {

    @Test(arguments: [false, true])
    func cachedDrawMatchesUncachedDraw(flipped: Bool) throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let rect = CGRect(x: 0, y: 0, width: 40, height: 30)
        let cache = CGFilterLayerCache()

        let uncached = try Self.render(flipped: flipped) { $0.draw(svg, in: rect) }
        let first = try Self.render(flipped: flipped) {
            $0.draw(svg, in: rect, baseCTM: nil, filterCache: cache)
        }
        #expect(cache.hitCount == 0)
        #expect(cache.count == 3)

        let second = try Self.render(flipped: flipped) {
            $0.draw(svg, in: rect, baseCTM: nil, filterCache: cache)
        }
        // the outer filter is drawn from the cache; its nested filter is skipped with it
        #expect(cache.hitCount == 2)
        #expect(first == uncached)
        #expect(second == uncached)
    }

    @Test
    func differentSVGEmptiesCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let other = try #require(SVG(xml: Self.filtered.replacingOccurrences(of: "red", with: "blue")))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filterCache: cache) }
        #expect(cache.count == 3)

        let drawn = try Self.render { $0.draw(other, in: nil, baseCTM: nil, filterCache: cache) }
        #expect(cache.hitCount == 0)
        #expect(drawn == (try Self.render { $0.draw(other, in: nil) }))
    }

    @Test
    func equalSVGKeepsCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let reparsed = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filterCache: cache) }
        _ = try Self.render { $0.draw(reparsed, in: nil, baseCTM: nil, filterCache: cache) }
        #expect(cache.hitCount == 2)
    }

    @Test
    func differentSizeEmptiesCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: CGRect(x: 0, y: 0, width: 40, height: 30), baseCTM: nil, filterCache: cache) }
        let resized = try Self.render {
            $0.draw(svg, in: CGRect(x: 0, y: 0, width: 60, height: 45), baseCTM: nil, filterCache: cache)
        }
        #expect(cache.hitCount == 0)
        #expect(cache.count == 3)
        #expect(resized == (try Self.render { $0.draw(svg, in: CGRect(x: 0, y: 0, width: 60, height: 45)) }))
    }

    @Test
    func movedContextMissesCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filterCache: cache) }
        let moved = try Self.render {
            $0.translateBy(x: 0.5, y: 0)
            $0.draw(svg, in: nil, baseCTM: nil, filterCache: cache)
        }
        #expect(cache.hitCount == 0)
        let expected = try Self.render {
            $0.translateBy(x: 0.5, y: 0)
            $0.draw(svg, in: nil)
        }
        #expect(moved == expected)
    }

    @Test
    func slicesAreEachCached() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let rect = CGRect(x: 0, y: 0, width: 64, height: 48)
        let insets: (CGFloat, CGFloat, CGFloat, CGFloat) = (5, 5, 5, 5)
        let cache = CGFilterLayerCache()

        let uncached = try Self.render { $0.draw(svg, in: rect, capInsets: insets, byTiling: false) }
        _ = try Self.render {
            $0.draw(svg, in: rect, capInsets: insets, byTiling: false, tileScale: nil, filterCache: cache)
        }
        let second = try Self.render {
            $0.draw(svg, in: rect, capInsets: insets, byTiling: false, tileScale: nil, filterCache: cache)
        }
        #expect(cache.hitCount > 0)
        #expect(second == uncached)
    }

    @Test
    func entriesPerLayerAreBounded() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()
        for offset in 0..<20 {
            _ = try Self.render {
                $0.translateBy(x: CGFloat(offset), y: 0)
                $0.draw(svg, in: nil, baseCTM: nil, filterCache: cache)
            }
        }
        #expect(cache.count <= 3 * CGFilterLayerCache.maxEntriesPerLayer)
    }

    @Test
    func matchingPopSkipsNestedLayers() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let commands = svg.commands
        let first = try #require(commands.firstIndex {
            if case .pushFilterLayer = $0 { return true } else { return false }
        })
        let end = try #require(RendererCommand.matchingPop(in: commands, from: first))
        let pushes = commands[first...end].filter { if case .pushFilterLayer = $0 { true } else { false } }.count
        let pops = commands[first...end].filter { if case .popFilterLayer = $0 { true } else { false } }.count
        #expect(pushes == pops)
        #expect(pushes == 2)
    }

    // a filter nested inside another, then a sibling filter
    static let filtered = """
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="15">
      <filter id="shift" x="-50%" y="-50%" width="200%" height="200%">
        <feOffset dx="1" dy="1" result="o"/>
        <feColorMatrix in="o" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 1  0 0 0 0.5 0"/>
        <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id="blur"><feGaussianBlur stdDeviation="0.8"/></filter>
      <g filter="url(#shift)">
        <rect x="2" y="2" width="6" height="5" fill="red"/>
        <circle cx="12" cy="6" r="3" fill="green" filter="url(#blur)"/>
      </g>
      <rect x="4" y="10" width="10" height="3" fill="orange" filter="url(#blur)"/>
    </svg>
    """

    static func render(flipped: Bool = false, _ draw: (CGContext) -> Void) throws -> [UInt8] {
        let width = 128, height = 96
        let ctx = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                         bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        if flipped {
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
        }
        ctx.scaleBy(x: 2, y: 2)
        draw(ctx)
        let data = try #require(ctx.data)
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
    }
}
#endif
