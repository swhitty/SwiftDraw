//
//  SVG.swift
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

import SwiftDrawDOM
public import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

public final class SVGGCache: Sendable {

    public static let shared = SVGGCache()

    nonisolated(unsafe)private let cache: NSCache<NSURL, Box<SVG>>

    public init(totalCostLimit: Int = defaultTotalCostLimit) {
        self.cache = NSCache()
        self.cache.totalCostLimit = totalCostLimit
    }

    public func svg(fileURL: URL) -> SVG? {
        cache.object(forKey: fileURL as NSURL)?.value
    }

    public func setSVG(_ svg: SVG, for fileURL: URL) {
        cache.setObject(Box(svg), forKey: fileURL as NSURL, cost: svg.commands.estimatedCost)
    }

    final class Box<T: Hashable>: NSObject {
        let value: T
        init(_ value: T) { self.value = value }
    }

    public static var defaultTotalCostLimit: Int {
    #if canImport(WatchKit)
        // 2 MB
        return 2 * 1024 * 1024
    #elseif canImport(AppKit)
        // 200 MB
        return 200 * 1024 * 1024
    #else
        // 50 MB
        return 50 * 1024 * 1024
    #endif
    }
}
#endif
