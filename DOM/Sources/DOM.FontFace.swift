//
//  DOM.FontFace.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 14/2/26.
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

import Foundation

package extension DOM {

    enum FontFamily: Hashable {
        case keyword(Keyword)
        case name(String)

        package enum Keyword: String {
            case serif
            case sansSerif = "sans-serif"
            case monospace
            case cursive
            case fantasy
        }
    }

    struct FontFace: Hashable {
        package var family: String
        /// The `src` descriptor: sources in order of preference; the first one that loads is used.
        package var src: [Source]
        /// The `font-weight` descriptor: one weight, or a range for a variable font. Defaults to 400.
        package var weight: ClosedRange<Int>
        /// The `font-style` descriptor. Defaults to normal.
        package var style: FontStyle

        package enum Source: Hashable {
            case url(url: DOM.URL, format: String?)
            /// An installed font by its full name or PostScript name (CSS Fonts 4 §4.3.2).
            case local(String)
        }

        package init(family: String, src: [Source], weight: ClosedRange<Int> = 400...400, style: FontStyle = .normal) {
            self.family = family
            self.src = src
            self.weight = weight
            self.style = style
        }

        package init(family: String, src: Source, weight: ClosedRange<Int> = 400...400, style: FontStyle = .normal) {
            self.init(family: family, src: [src], weight: weight, style: style)
        }
    }
}

package extension DOM.FontFamily {

    var name: String {
        switch self {
        case .name(let s):
            return s
        case .keyword(let k):
            return k.rawValue
        }
    }
}
