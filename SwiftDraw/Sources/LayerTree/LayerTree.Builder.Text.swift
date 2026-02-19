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

import SwiftDrawDOM
import Foundation
#if canImport(CoreText)
import CoreText
#endif

extension LayerTree.Builder {

#if canImport(CoreText)
    static func makeOffset(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Size {
        let font = CGProvider.createCTFont(for: attributes.font, size: attributes.size)
        let line = text.toLine(font: font)
        return LayerTree.Size(
            makeXOffset(line: line, anchor: attributes.anchor),
            makeYOffset(font: font, baseline: attributes.baseline)
        )
    }

    static func makeXOffset(line: CTLine, anchor: DOM.TextAnchor) -> LayerTree.Float {
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        switch anchor {
        case .start:
           return 0
        case .middle:
            return LayerTree.Float(-width / 2)
        case .end:
            return LayerTree.Float(-width)
        }
    }

    static func makeYOffset(font: CTFont, baseline: DOM.TextBaseline) -> LayerTree.Float {
        switch baseline {
        case .central:
            let capHeight = CTFontGetCapHeight(font)
            return LayerTree.Float(capHeight / 2)
        case .alphabetic, .auto:
            return 0
        case .hanging:
            let leading = CTFontGetLeading(font)
            let ascent = CTFontGetAscent(font) - leading
            return LayerTree.Float(-ascent)
        case .middle:
            let xHeight = CTFontGetXHeight(font)
            return LayerTree.Float(xHeight / 2)
        }
    }
#else
    static func makeOffset(for text: String, with attributes: LayerTree.TextAttributes) -> LayerTree.Size {
        return .zero
    }
#endif

}

extension DOM.FontFamily {

    var fontName: String {
        switch self {
        case .name(let s):
            return s
        case .keyword(.serif):
            return "Times"
        case .keyword(.sansSerif):
            return "Helvetica"
        case .keyword(.monospace):
            return "Courier"
        case .keyword(.fantasy):
            return "Papyrus"
        case .keyword(.cursive):
            return "Apple Chancery"
        }
    }
}
