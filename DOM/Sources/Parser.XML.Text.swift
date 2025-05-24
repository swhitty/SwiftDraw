//
//  Parser.XML.Text.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
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

import Foundation

extension XMLParser {

    func parseText(_ att: any AttributeParser, element: XML.Element) throws -> DOM.Text? {
        guard
            let text = element.innerText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else {
            return nil
        }

        return try parseText(att, value: text)
    }

    func parseAnchor(_ att: any AttributeParser, element: XML.Element) throws -> DOM.Anchor? {
        let anchor = DOM.Anchor()
        anchor.href = try att.parseUrl("href")
        return anchor
    }

    func parseText(_ att: any AttributeParser, value: String) throws -> DOM.Text {
        let element = DOM.Text(value: value)
        element.x = try att.parseCoordinate("x")
        element.y = try att.parseCoordinate("y")
        return element
    }
}
