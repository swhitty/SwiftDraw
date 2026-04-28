//
//  Renderer.SFSymbol+ClipPath.swift
//  SwiftDraw
//
//  Created by SwiftDraw contributors
//  Copyright 2026 Simon Whitty
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
import CoreGraphics
import SwiftDrawDOM

extension SFSymbolRenderer {

    /// Bake the intersection of `path` with the union of `clipShapes` into a single LayerTree.Path.
    /// Returns `nil` when the result is empty (path lies entirely outside the clip region).
    /// Returns the original `path` unchanged when the running platform predates CGPath boolean ops.
    /// `clipCTM` is applied to each clip shape so it sits in the same coordinate space as `path`.
    static func intersect(path: LayerTree.Path,
                          with clipShapes: [LayerTree.ClipShape],
                          clipRule: LayerTree.FillRule?,
                          clipUnits: LayerTree.ClipUnits,
                          clipCTM: LayerTree.Transform.Matrix) -> LayerTree.Path? {
        guard !clipShapes.isEmpty else { return path }

        let pathCG = CGProvider().createPath(from: .path(path))
        guard !pathCG.isEmpty else { return nil }

        let unitsTransform: LayerTree.Transform.Matrix
        switch clipUnits {
        case .userSpaceOnUse:
            unitsTransform = .identity
        case .objectBoundingBox:
            let bounds = path.bounds
            guard bounds.width > 0, bounds.height > 0 else { return nil }
            unitsTransform = LayerTree.Transform.Matrix(
                a: bounds.width, b: 0,
                c: 0, d: bounds.height,
                tx: bounds.minX, ty: bounds.minY
            )
        }

        let clipCG = makeUnionedCGPath(
            from: clipShapes,
            preCTM: unitsTransform,
            postCTM: clipCTM
        )
        guard !clipCG.isEmpty else { return nil }

        let rule: CGPathFillRule = (clipRule == .evenodd) ? .evenOdd : .winding

        if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            let intersected = pathCG.intersection(clipCG, using: rule)
            if intersected.isEmpty { return nil }
            return intersected.makePath()
        } else {
            // Fall back for older deployment targets: keep the path when its bbox lies
            // entirely inside the clip bbox; drop it when entirely outside; otherwise
            // pass it through unchanged so existing behavior is preserved.
            return fallbackIntersect(pathCG: pathCG, clipCG: clipCG, original: path)
        }
    }

    private static func makeUnionedCGPath(from clipShapes: [LayerTree.ClipShape],
                                          preCTM: LayerTree.Transform.Matrix,
                                          postCTM: LayerTree.Transform.Matrix) -> CGPath {
        let provider = CGProvider()
        let union = CGMutablePath()
        for clipShape in clipShapes {
            let combined = preCTM
                .concatenated(clipShape.transform)
                .concatenated(postCTM)
            let transform = provider.createTransform(from: combined)
            let shapePath = provider.createPath(from: clipShape.shape)
            union.addPath(shapePath, transform: transform)
        }
        return union
    }

    private static func fallbackIntersect(pathCG: CGPath, clipCG: CGPath, original: LayerTree.Path) -> LayerTree.Path? {
        let pathBounds = pathCG.boundingBoxOfPath
        let clipBounds = clipCG.boundingBoxOfPath
        if !pathBounds.intersects(clipBounds) { return nil }
        return original
    }
}
#endif
