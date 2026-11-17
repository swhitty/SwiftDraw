//
//  CGFilterLayerCache.swift
//  SwiftDraw
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
import CoreGraphics
import Foundation
import SwiftDrawDOM

/// The filtered results of one SVG's filter layers, drawn at one size.
///
/// Filters are evaluated per pixel on the CPU, so redrawing an SVG with filters is slow; the result of
/// each filter layer only depends on its commands and the device space it is drawn in, so a redraw in
/// the same space reuses it. A few entries are kept per filter layer (one per slice when drawn 9-sliced),
/// the oldest replaced when the device space changes, so the bitmaps held are bounded by the SVG's filter
/// layers. It is emptied when drawn with another SVG or at another size.
///
/// Views draw with `shared(for:size:)`, which outlives them (see there).
final class CGFilterLayerCache: Sendable {

    struct Key: Equatable {
        // the filter layer's pushFilterLayer command within the SVG's commands
        var index: Int
        var toDevice: CGAffineTransform
        var deviceRect: CGRect
        var maxPixels: Int
        var isVector: Bool
        var colorSpace: CGColorSpace?
    }

    struct Entry {
        var key: Key
        var image: CGImage
        // the device pixels the image covers
        var deviceRect: CGRect
        // image pixels per device pixel
        var scale: CGFloat
    }

    private struct State {
        var commands: [RendererCommand<CGTypes>]?
        var size: CGSize?
        var entries = [Int: [Entry]]()
        var hits = 0
        // set when held by the shared caches, to update its cost there
        var sharedKey: SharedKey?
        // the fill running in the background, which other draws wait for rather than start another
        var fillTask: Task<Void, Never>?
        // callers waiting for fillTask
        var fillWaiters = 0

        var byteCount: Int {
            entries.values.joined().reduce(0) { $0 + $1.image.bytesPerRow * $1.image.height }
        }
    }

    private let state = Mutex(State())

    init() {}

    /// Empties the cache unless it was filled drawing an SVG with the same commands at the same size.
    func prepare(for svg: SVG, size: CGSize) {
        state.withLock {
            if size == $0.size, let commands = $0.commands, Self.isSame(commands, svg.commands) { return }
            $0.commands = svg.commands
            $0.size = size
            $0.entries.removeAll()
        }
    }

    func removeAll() {
        state.withLock {
            $0.commands = nil
            $0.size = nil
            $0.entries.removeAll()
        }
    }

    var count: Int {
        state.withLock { $0.entries.values.reduce(0) { $0 + $1.count } }
    }

    // the bytes of the bitmaps held
    var byteCount: Int {
        state.withLock { $0.byteCount }
    }

    // filter layers drawn from the cache so far
    var hitCount: Int {
        state.withLock { $0.hits }
    }

    func entry(for key: Key) -> Entry? {
        state.withLock {
            guard let entry = $0.entries[key.index]?.first(where: { $0.key == key }) else { return nil }
            $0.hits += 1
            return entry
        }
    }

    func store(_ entry: Entry) {
        let shared: (key: SharedKey, cost: Int)? = state.withLock {
            var layer = $0.entries[entry.key.index, default: []]
            layer.removeAll { $0.key == entry.key }
            if layer.count >= Self.maxEntriesPerLayer {
                layer.removeFirst(layer.count - Self.maxEntriesPerLayer + 1)
            }
            layer.append(entry)
            $0.entries[entry.key.index] = layer
            guard let sharedKey = $0.sharedKey else { return nil }
            return (sharedKey, $0.byteCount)
        }

        if let shared {
            Self.sharedCaches.setObject(self, forKey: shared.key, cost: shared.cost)
        }
    }

    /// Runs `work` in the background to fill the cache, or waits for the fill already running.
    func fill(_ work: @escaping @Sendable () -> Void) async {
        let task = state.withLock {
            $0.fillWaiters += 1
            if let task = $0.fillTask { return task }
            let task = Task.detached(priority: .userInitiated, operation: work)
            $0.fillTask = task
            return task
        }
        await task.value
        state.withLock {
            $0.fillWaiters -= 1
            if $0.fillTask == task { $0.fillTask = nil }
        }
    }

    // callers waiting for the fill running now
    var fillWaiterCount: Int {
        state.withLock { $0.fillWaiters }
    }

    // a 9-slice draws each filter layer in 9 device spaces per frame
    static let maxEntriesPerLayer = 9

    /// The cache for drawing svg at size, shared by every view that does.
    ///
    /// A view's own state does not last: a row of a LazyVStack is destroyed when scrolled away and created
    /// again when scrolled back, which would evaluate every filter again. The shared caches are held in an
    /// NSCache costed by the bytes of their bitmaps, so they are bounded and evicted under memory pressure.
    static func shared(for svg: SVG, size: CGSize) -> CGFilterLayerCache {
        let key = SharedKey(commands: svg.commands, size: size)
        if let cache = sharedCaches.object(forKey: key) {
            return cache
        }
        let cache = CGFilterLayerCache()
        cache.state.withLock { $0.sharedKey = key }
        sharedCaches.setObject(cache, forKey: key, cost: 0)
        return cache
    }

    static let sharedCostLimit = 128 * 1024 * 1024

    // NSCache is thread-safe
    nonisolated(unsafe) static let sharedCaches: NSCache<SharedKey, CGFilterLayerCache> = {
        let cache = NSCache<SharedKey, CGFilterLayerCache>()
        cache.totalCostLimit = sharedCostLimit
        return cache
    }()

    // immutable
    final class SharedKey: NSObject, @unchecked Sendable {
        let commands: [RendererCommand<CGTypes>]
        let size: CGSize
        private let hashValue_: Int

        init(commands: [RendererCommand<CGTypes>], size: CGSize) {
            self.commands = commands
            self.size = size
            var hasher = Hasher()
            hasher.combine(commands.count)
            hasher.combine(size.width)
            hasher.combine(size.height)
            self.hashValue_ = hasher.finalize()
        }

        override var hash: Int { hashValue_ }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? SharedKey else { return false }
            return size == other.size && CGFilterLayerCache.isSame(commands, other.commands)
        }
    }

    // the same storage (the usual case, cheap) or equal commands (draws the same, compared only on change)
    static func isSame(_ lhs: [RendererCommand<CGTypes>], _ rhs: [RendererCommand<CGTypes>]) -> Bool {
        let lhsBase = lhs.withUnsafeBufferPointer { $0.baseAddress }
        let rhsBase = rhs.withUnsafeBufferPointer { $0.baseAddress }
        if lhsBase == rhsBase, lhs.count == rhs.count { return true }
        return lhs == rhs
    }
}

/// How one draw uses a filter layer cache: made for the draw, on its thread.
final class CGFilterLayerDraw {
    let cache: CGFilterLayerCache

    /// A filter layer missing from the cache is drawn unfiltered, rather than evaluated, and `didDefer` is set:
    /// the caller fills the cache in the background (see `CGFilterLayerFill`) and draws again.
    let defersMisses: Bool

    /// Filter layers drawn into `context` are rasterized as for a vector (true) or bitmap (false) context,
    /// whatever it is, so that a bitmap filling the cache in the background makes the entries a SwiftUI
    /// Canvas (a vector context) will look up.
    let target: (context: CGContext, isVector: Bool)?

    // set while drawing, on the drawing thread
    private(set) var didDefer = false

    init(_ cache: CGFilterLayerCache, defersMisses: Bool = false, target: (context: CGContext, isVector: Bool)? = nil) {
        self.cache = cache
        self.defersMisses = defersMisses
        self.target = target
    }

    func deferMiss() {
        didDefer = true
    }

    // whether filter layers drawn into parent are rasterized as for a vector context
    func isVector(_ parent: CGContext) -> Bool {
        if let target, target.context === parent {
            return target.isVector
        }
        return !parent.isBitmapContext
    }
}

/// A draw that deferred filter layers, replayed into a bitmap in the background to fill the cache.
///
/// The bitmap gets the device space and clip the deferred draw had, and rasterizes filter layers as that
/// context would, so the entries it stores are the ones the draw looks up when repeated.
struct CGFilterLayerFill: Sendable {
    var cache: CGFilterLayerCache
    var toDevice: CGAffineTransform
    // the clip of the context in its user space
    var clip: CGRect
    var isVector: Bool
    var draw: @Sendable (CGContext, CGFilterLayerDraw) -> Void

    /// nil when the context's clip is not within positive device space, which a bitmap can not cover
    init?(
        context: CGContext,
        cache: CGFilterLayerCache,
        draw: @escaping @Sendable (CGContext, CGFilterLayerDraw) -> Void
    ) {
        let toDevice = context.userSpaceToDeviceSpaceTransform
        let clip = context.boundingBoxOfClipPath
        guard !clip.isNull, !clip.isInfinite else { return nil }
        let device = clip.applying(toDevice)
        guard !device.isEmpty, device.minX >= 0, device.minY >= 0, device.maxX.isFinite, device.maxY.isFinite,
            device.maxX * device.maxY <= CGFloat(Self.maxPixels)
        else { return nil }
        self.cache = cache
        self.toDevice = toDevice
        self.clip = clip
        self.isVector = !context.isBitmapContext
        self.draw = draw
    }

    static let maxPixels = 8192 * 8192

    /// Fills the cache in the background; a fill already running is waited for instead.
    func perform() async {
        let fill = self
        await cache.fill { fill.replay() }
    }

    func replay() {
        let device = clip.applying(toDevice)
        guard
            let bitmap = CGContext.makeFilterLayer(
                width: Int(device.maxX.rounded(.up)),
                height: Int(device.maxY.rounded(.up)),
                colorSpace: nil
            )
        else { return }
        // a bitmap's device space has its own transform (y down from the first row): the CTM undoes it
        let base = bitmap.userSpaceToDeviceSpaceTransform
        bitmap.concatenate(toDevice.concatenating(base.inverted()))
        bitmap.clip(to: clip)
        draw(bitmap, CGFilterLayerDraw(cache, target: (bitmap, isVector)))
    }
}

extension RendererCommand<CGTypes> {

    // the index of the popFilterLayer matching the pushFilterLayer at index
    static func matchingPop(in commands: [RendererCommand<CGTypes>], from index: Int) -> Int? {
        var depth = 0
        for i in index..<commands.count {
            switch commands[i] {
            case .pushFilterLayer:
                depth += 1
            case .popFilterLayer:
                depth -= 1
                if depth == 0 { return i }
            default:
                break
            }
        }
        return nil
    }
}
#endif
