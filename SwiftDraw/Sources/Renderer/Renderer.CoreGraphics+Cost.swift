//
//  Renderer.CoreGraphics+Cost.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/8/25.
//  Copyright 2025 WhileLoop Pty Ltd. All rights reserved.
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

extension [RendererCommand<CGTypes>] {

    var estimatedCost: Int {
        let commandCost = MemoryLayout<Self>.stride * count
        let pathCost = Set(allPaths).reduce(0) { $0 + $1.estimatedCost }
        let imageCost = Set(allImages).reduce(0) { $0 + $1.estimatedCost }
        return commandCost + pathCost + imageCost
    }
}

extension CGPath {

    var estimatedCost: Int {
        var total = 0
        applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint, .closeSubpath:
                total += MemoryLayout<CGPathElement>.stride + MemoryLayout<CGPoint>.stride
            case .addQuadCurveToPoint:
                total += MemoryLayout<CGPathElement>.stride + 2 * MemoryLayout<CGPoint>.stride
            case .addCurveToPoint:
                total += MemoryLayout<CGPathElement>.stride + 3 * MemoryLayout<CGPoint>.stride
            @unknown default:
                break
            }
        }
        return MemoryLayout<CGPath>.size + total
    }
}

extension CGImage {
    var estimatedCost: Int { bytesPerRow * height }
}

extension RendererCommand<CGTypes> {

    var allPaths: [CGPath] {
        switch self {
        case .setClip(path: let p, rule: _):
            return [p]
        case .setFillPattern(let p):
            return p.contents.allPaths
        case .stroke(let p):
            return [p]
        case .clipStrokeOutline(let p):
            return [p]
        case .fill(let p, rule: _):
            return [p]
        default:
            return []
        }
    }

    var allImages: [CGImage] {
        switch self {
        case .setFillPattern(let p):
            return p.contents.allImages
        case .draw(image: let i, in: _):
            return [i]
        default:
            return []
        }
    }
}

extension [RendererCommand<CGTypes>] {

    var allPaths: [CGPath] {
        var paths = [CGPath]()
        for command in self {
            paths.append(contentsOf: command.allPaths)
        }
        return paths
    }

    var allImages: [CGImage] {
        var images = [CGImage]()
        for command in self {
            images.append(contentsOf: command.allImages)
        }
        return images
    }
}

#endif
