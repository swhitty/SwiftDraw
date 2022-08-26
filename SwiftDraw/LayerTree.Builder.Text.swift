//
//  LayerTree.Builder.Text.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/8/22.
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

// Convert a DOM.SVG into a layer tree

import Foundation
#if canImport(CoreText)
import CoreText
#endif

extension LayerTree.Builder {

#if canImport(CoreText)
    static func makeXOffset(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        let font = CTFontCreateWithName(attributes.fontName as CFString,
                                        CGFloat(attributes.size),
                                        nil)
        guard let bounds = text.toPath(font: font)?.boundingBoxOfPath else { return 0 }
        switch attributes.anchor {
        case .start:
            return LayerTree.Float(bounds.minX)
        case .middle:
            return LayerTree.Float(-bounds.midX)
        case .end:
            return LayerTree.Float(-bounds.maxX)
        }
    }
#else
    static func makeXOffset(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Float {
        return 0
    }
#endif

    
}
