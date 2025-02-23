//
//  SVG+Hashable.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 23/2/25.
//  Copyright 2025 Simon Whitty
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

#if canImport(CoreGraphics) && compiler(<6.0)
import CoreGraphics

public extension SVG {

    func hash(into hasher: inout Hasher) {
        size.width.hash(into: &hasher)
        size.height.hash(into: &hasher)
        commands.hash(into: &hasher)
    }
}

extension RendererCommand<CGTypes> {

    func hash(into hasher: inout Hasher) {
        switch self {
        case .pushState:
            "pushState".hash(into: &hasher)
        case .popState:
            "popState".hash(into: &hasher)
        case let .concatenate(transform: transform):
            "concatenate".hash(into: &hasher)
            transform.a.hash(into: &hasher)
            transform.b.hash(into: &hasher)
            transform.c.hash(into: &hasher)
            transform.d.hash(into: &hasher)
            transform.ty.hash(into: &hasher)
            transform.tx.hash(into: &hasher)
        case let .translate(tx: tx, ty: ty):
            "translate".hash(into: &hasher)
            tx.hash(into: &hasher)
            ty.hash(into: &hasher)
        case let .rotate(angle: angle):
            "rotate".hash(into: &hasher)
            angle.hash(into: &hasher)
        case let .scale(sx: sx, sy: sy):
            "scale".hash(into: &hasher)
            sx.hash(into: &hasher)
            sy.hash(into: &hasher)
        case let .setFill(color: color):
            "setFill".hash(into: &hasher)
            color.hash(into: &hasher)
        case let .setFillPattern(pattern):
            "setFillPattern".hash(into: &hasher)
            pattern.hash(into: &hasher)
        case let .setStroke(color: color):
            "setStroke".hash(into: &hasher)
            color.hash(into: &hasher)
        case let .setLine(width: width):
            "setLine".hash(into: &hasher)
            width.hash(into: &hasher)
        case let .setLineCap(cap):
            "setLineCap".hash(into: &hasher)
            cap.hash(into: &hasher)
        case let .setLineJoin(join):
            "setLineJoin".hash(into: &hasher)
            join.hash(into: &hasher)
        case let .setLineMiter(limit: limit):
            "setLineMiter".hash(into: &hasher)
            limit.hash(into: &hasher)
        case let .setClip(path: path, rule: rule):
            "setClip".hash(into: &hasher)
            path.hash(into: &hasher)
            rule.hash(into: &hasher)
        case let .setClipMask(mask, frame: frame):
            "setClip".hash(into: &hasher)
            mask.hash(into: &hasher)
            frame.origin.x.hash(into: &hasher)
            frame.origin.y.hash(into: &hasher)
            frame.size.width.hash(into: &hasher)
            frame.size.height.hash(into: &hasher)
        case let .setAlpha(alpha):
            "setAlpha".hash(into: &hasher)
            alpha.hash(into: &hasher)
        case let .setBlend(mode: mode):
            "setBlend".hash(into: &hasher)
            mode.hash(into: &hasher)
        case let .stroke(stroke):
            "stroke".hash(into: &hasher)
            stroke.hash(into: &hasher)
        case let .clipStrokeOutline(outline):
            "clipStrokeOutline".hash(into: &hasher)
            outline.hash(into: &hasher)
        case let .fill(fill, rule: rule):
            "fill".hash(into: &hasher)
            fill.hash(into: &hasher)
            rule.hash(into: &hasher)
        case let .draw(image: image, in: bounds):
            "draw".hash(into: &hasher)
            image.hash(into: &hasher)
            bounds.origin.x.hash(into: &hasher)
            bounds.origin.y.hash(into: &hasher)
            bounds.size.width.hash(into: &hasher)
            bounds.size.height.hash(into: &hasher)
        case let .drawLinearGradient(gradient, from: from, to: to):
            "drawLinearGradient".hash(into: &hasher)
            gradient.hash(into: &hasher)
            from.x.hash(into: &hasher)
            from.y.hash(into: &hasher)
            to.x.hash(into: &hasher)
            to.y.hash(into: &hasher)
        case let .drawRadialGradient(gradient, startCenter: startCenter, startRadius: startRadius, endCenter: endCenter, endRadius: endRadius):
            "drawRadialGradient".hash(into: &hasher)
            gradient.hash(into: &hasher)
            startCenter.x.hash(into: &hasher)
            startCenter.y.hash(into: &hasher)
            startRadius.hash(into: &hasher)
            endCenter.x.hash(into: &hasher)
            endCenter.y.hash(into: &hasher)
            endRadius.hash(into: &hasher)
        case .pushTransparencyLayer:
            "pushTransparencyLayer".hash(into: &hasher)
        case .popTransparencyLayer:
            "popTransparencyLayer".hash(into: &hasher)
        }
    }
}
#endif
