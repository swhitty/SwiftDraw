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

/// The filtered results of one SVG's filter layers, drawn at one size.
///
/// Filters are evaluated per pixel on the CPU, so redrawing an SVG with filters is slow; the result of
/// each filter layer only depends on its commands and the device space it is drawn in, so a redraw in
/// the same space reuses it. A few entries are kept per filter layer (one per slice when drawn 9-sliced),
/// the oldest replaced when the device space changes, so the bitmaps held are bounded by the SVG's filter
/// layers. It is emptied when drawn with another SVG or at another size.
///
/// Views draw with `shared(for:size:)`, which outlives them (see there).
final class CGFilterLayerCache: @unchecked Sendable {

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

    private let lock = NSLock()
    private var commands: [RendererCommand<CGTypes>]?
    private var size: CGSize?
    private var entries = [Int: [Entry]]()
    private var hits = 0
    // set when held by the shared caches, to update its cost there
    private var sharedKey: SharedKey?

    init() { }

    /// Empties the cache unless it was filled drawing an SVG with the same commands at the same size.
    func prepare(for svg: SVG, size: CGSize) {
        lock.lock()
        defer { lock.unlock() }
        if size == self.size, let commands, Self.isSame(commands, svg.commands) { return }
        commands = svg.commands
        self.size = size
        entries.removeAll()
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        commands = nil
        size = nil
        entries.removeAll()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.values.reduce(0) { $0 + $1.count }
    }

    // the bytes of the bitmaps held
    var byteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.values.joined().reduce(0) { $0 + $1.image.bytesPerRow * $1.image.height }
    }

    // filter layers drawn from the cache so far
    var hitCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return hits
    }

    func entry(for key: Key) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key.index]?.first(where: { $0.key == key }) else { return nil }
        hits += 1
        return entry
    }

    func store(_ entry: Entry) {
        lock.lock()
        var layer = entries[entry.key.index, default: []]
        layer.removeAll { $0.key == entry.key }
        if layer.count >= Self.maxEntriesPerLayer {
            layer.removeFirst(layer.count - Self.maxEntriesPerLayer + 1)
        }
        layer.append(entry)
        entries[entry.key.index] = layer
        let sharedKey = self.sharedKey
        lock.unlock()

        if let sharedKey {
            Self.sharedCaches.setObject(self, forKey: sharedKey, cost: byteCount)
        }
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
        cache.sharedKey = key
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

    final class SharedKey: NSObject {
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
