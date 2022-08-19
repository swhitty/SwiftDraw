//
//  DOM.PresentationAttributes.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/8/22.
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

import Foundation

extension DOM {

    // PresentationAttributes cascade;
    // element.attributes --> .element() --> .class() ---> .id() ---> element.style ---> layerTree.state

    struct PresentationAttributes {
        var opacity: DOM.Float?
        var display: DOM.DisplayMode?
        var color: DOM.Color?

        var stroke: DOM.Fill?
        var strokeWidth: DOM.Float?
        var strokeOpacity: DOM.Float?
        var strokeLineCap: DOM.LineCap?
        var strokeLineJoin: DOM.LineJoin?
        var strokeDashArray: [DOM.Float]?

        var fill: DOM.Fill?
        var fillOpacity: DOM.Float?
        var fillRule: DOM.FillRule?

        var fontFamily: String?
        var fontSize: Float?

        var transform: [DOM.Transform]?
        var clipPath: DOM.URL?
        var clipRule: DOM.FillRule?
        var mask: DOM.URL?
        var filter: DOM.URL?
    }
}
