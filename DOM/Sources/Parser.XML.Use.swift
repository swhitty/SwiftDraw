//
//  Parser.XML.Use.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/2/17.
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

extension XMLParser {

    func parseUse(_ att: any AttributeParser) throws -> DOM.Use {
        let href: DOM.URL = try {
            do {
                return try att.parseUrl("href")
            } catch XMLParser.Error.missingAttribute(_) {
                /// Backward compatibility for the deprecated "xlink:href"
                /// https://www.w3.org/TR/SVG/linking.html#XLinkRefAttrs
                return try att.parseUrl("xlink:href")
            }
        }()

        let use = DOM.Use(href: href)
        use.x = parseDefaultedLength(att, "x", .horizontal)
        use.y = parseDefaultedLength(att, "y", .vertical)
        // only a referenced <symbol> uses these: missing (or invalid) falls back to the symbol's
        // own size, and then to 100% of the enclosing viewport
        use.width = parseDefaultedLength(att, "width", .horizontal)
        use.height = parseDefaultedLength(att, "height", .vertical)
        use.viewport = lengthContext.viewports.last

        return use
    }
}
