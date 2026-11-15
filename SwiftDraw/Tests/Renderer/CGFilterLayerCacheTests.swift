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
import SwiftDrawDOM

struct CGFilterLayerCacheTests {

    @Test(arguments: [false, true])
    func cachedDrawMatchesUncachedDraw(flipped: Bool) throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let rect = CGRect(x: 0, y: 0, width: 40, height: 30)
        let cache = CGFilterLayerCache()

        let uncached = try Self.render(flipped: flipped) { $0.draw(svg, in: rect) }
        let first = try Self.render(flipped: flipped) {
            $0.draw(svg, in: rect, baseCTM: nil, filters: CGFilterLayerDraw(cache))
        }
        #expect(cache.hitCount == 0)
        #expect(cache.count == 3)

        let second = try Self.render(flipped: flipped) {
            $0.draw(svg, in: rect, baseCTM: nil, filters: CGFilterLayerDraw(cache))
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

        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        #expect(cache.count == 3)

        let drawn = try Self.render { $0.draw(other, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        #expect(cache.hitCount == 0)
        let expected = try Self.render { $0.draw(other, in: nil) }
        #expect(drawn == expected)
    }

    @Test
    func equalSVGKeepsCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let reparsed = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        _ = try Self.render { $0.draw(reparsed, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        #expect(cache.hitCount == 2)
    }

    @Test
    func differentSizeEmptiesCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: CGRect(x: 0, y: 0, width: 40, height: 30), baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        let resized = try Self.render {
            $0.draw(svg, in: CGRect(x: 0, y: 0, width: 60, height: 45), baseCTM: nil, filters: CGFilterLayerDraw(cache))
        }
        #expect(cache.hitCount == 0)
        #expect(cache.count == 3)
        let expected = try Self.render { $0.draw(svg, in: CGRect(x: 0, y: 0, width: 60, height: 45)) }
        #expect(resized == expected)
    }

    @Test
    func movedContextMissesCache() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()

        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        let moved = try Self.render {
            $0.translateBy(x: 0.5, y: 0)
            $0.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache))
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
            $0.draw(svg, in: rect, capInsets: insets, byTiling: false, tileScale: nil, filters: CGFilterLayerDraw(cache))
        }
        let second = try Self.render {
            $0.draw(svg, in: rect, capInsets: insets, byTiling: false, tileScale: nil, filters: CGFilterLayerDraw(cache))
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
                $0.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache))
            }
        }
        #expect(cache.count <= 3 * CGFilterLayerCache.maxEntriesPerLayer)
    }

    @Test
    func sharedCacheIsFoundAgainForSameSVGAndSize() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let size = CGSize(width: 41, height: 31)
        let cache = CGFilterLayerCache.shared(for: svg, size: size)
        _ = try Self.render { $0.draw(svg, in: CGRect(origin: .zero, size: size), baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        #expect(cache.byteCount > 0)

        // e.g. a LazyVStack row scrolled away and back: a new view, the same SVG
        let reparsed = try #require(SVG(xml: Self.filtered))
        #expect(CGFilterLayerCache.shared(for: svg, size: size) === cache)
        #expect(CGFilterLayerCache.shared(for: reparsed, size: size) === cache)
        #expect(CGFilterLayerCache.shared(for: svg, size: CGSize(width: 42, height: 31)) !== cache)
        let other = try #require(SVG(xml: Self.filtered.replacingOccurrences(of: "red", with: "blue")))
        #expect(CGFilterLayerCache.shared(for: other, size: size) !== cache)
    }

    @Test
    func byteCountIsTheBitmapsHeld() throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()
        #expect(cache.byteCount == 0)
        _ = try Self.render { $0.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache)) }
        #expect(cache.byteCount >= cache.count * 4)
        cache.removeAll()
        #expect(cache.byteCount == 0)
    }

    @Test(arguments: [false, true])
    func deferredDrawIsFilledInBackgroundThenHits(flipped: Bool) async throws {
        let svg = try #require(SVG(xml: Self.filtered))
        let rect = CGRect(x: 0, y: 0, width: 40, height: 30)
        let cache = CGFilterLayerCache()
        let uncached = try Self.render(flipped: flipped) { $0.draw(svg, in: rect) }

        var fill: CGFilterLayerFill?
        var deferred = false
        _ = try Self.render(flipped: flipped) { context in
            let layers = CGFilterLayerDraw(cache, defersMisses: true)
            fill = CGFilterLayerFill(context: context, cache: cache) { context, filters in
                context.draw(svg, in: rect, baseCTM: nil, filters: filters)
            }
            context.draw(svg, in: rect, baseCTM: nil, filters: layers)
            deferred = layers.didDefer
        }
        // nothing evaluated while drawing
        #expect(deferred)
        #expect(cache.count == 0)

        let deferredFill = try #require(fill)
        await deferredFill.perform()
        #expect(cache.count > 0)

        let redrawn = try Self.render(flipped: flipped) {
            $0.draw(svg, in: rect, baseCTM: nil, filters: CGFilterLayerDraw(cache))
        }
        #expect(cache.hitCount == 2)
        #expect(redrawn == uncached)
    }

    @Test
    func fillForVectorContextMatchesItsKeys() async throws {
        // a PDF context stands in for a SwiftUI Canvas: both are vector contexts
        let svg = try #require(SVG(xml: Self.filtered))
        let cache = CGFilterLayerCache()
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 40, height: 30)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let pdf = try #require(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        pdf.beginPage(mediaBox: &mediaBox)

        let layers = CGFilterLayerDraw(cache, defersMisses: true)
        let fill = try #require(CGFilterLayerFill(context: pdf, cache: cache) { context, filters in
            context.draw(svg, in: nil, baseCTM: nil, filters: filters)
        })
        pdf.draw(svg, in: nil, baseCTM: nil, filters: layers)
        #expect(layers.didDefer)
        #expect(fill.isVector)

        await fill.perform()
        let stored = cache.count
        #expect(stored == 3)

        pdf.draw(svg, in: nil, baseCTM: nil, filters: CGFilterLayerDraw(cache))
        pdf.endPage()
        pdf.closePDF()
        #expect(cache.hitCount == 2)
        #expect(cache.count == stored)
    }

    @Test
    func concurrentFillsRunOnce() async throws {
        let cache = CGFilterLayerCache()
        let runs = RunCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await cache.fill {
                        runs.increment()
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                }
            }
        }
        #expect(runs.value == 1)
    }

    final class RunCounter: Sendable {
        private let count = Mutex(0)
        var value: Int { count.withLock { $0 } }
        func increment() { count.withLock { $0 += 1 } }
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
