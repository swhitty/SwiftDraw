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

/// The filtered results of one SVG's filter layers, kept by a view that redraws the same SVG.
///
/// Filters are evaluated per pixel on the CPU, so redrawing an SVG with filters is slow; the result of
/// each filter layer only depends on its commands and the device space it is drawn in, so a redraw in
/// the same space reuses it. A few entries are kept per filter layer (one per slice when drawn 9-sliced),
/// the oldest replaced when the device space changes, so the bitmaps held are bounded by the SVG's filter
/// layers. It is emptied when the SVG or the size it is drawn at changes.
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
        defer { lock.unlock() }
        var layer = entries[entry.key.index, default: []]
        layer.removeAll { $0.key == entry.key }
        if layer.count >= Self.maxEntriesPerLayer {
            layer.removeFirst(layer.count - Self.maxEntriesPerLayer + 1)
        }
        layer.append(entry)
        entries[entry.key.index] = layer
    }

    // a 9-slice draws each filter layer in 9 device spaces per frame
    static let maxEntriesPerLayer = 9

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
