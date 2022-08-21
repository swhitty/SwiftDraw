//
//  Renderer.SFSymbol+CGPath.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 21/8/22.
//  Copyright 2022 Simon Whitty
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

extension SFSymbolRenderer {


    static func expandOutlines(for path: LayerTree.Path,
                               stroke: LayerTree.StrokeAttributes) -> LayerTree.Path? {

        var mediaBox = CGRect(x: 0.0, y: 0.0, width: 100, height: 100)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        let provider = CGProvider()

        ctx.setLineWidth(provider.createFloat(from: stroke.width))
        ctx.setLineJoin(provider.createLineJoin(from: stroke.join))
        ctx.setLineCap(provider.createLineCap(from: stroke.cap))
        ctx.setMiterLimit(provider.createFloat(from: stroke.miterLimit))
        ctx.addPath(provider.createPath(from: .path(path)))
        ctx.replacePathWithStrokedPath()
        guard let cgPath = ctx.path else {
            return nil
        }

        return cgPath.makePath()
    }
}
#endif
