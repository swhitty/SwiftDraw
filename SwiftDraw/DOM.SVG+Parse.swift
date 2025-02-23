//
//  DOM.SVG+Parse.swift
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

import Foundation

extension DOM.SVG {

    static func parse(fileURL url: URL, options: XMLParser.Options = .skipInvalidElements) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(contentsOf: url)
        let parser = XMLParser(options: options, filename: url.lastPathComponent)
        return try parser.parseSVG(element)
    }

    static func parse(data: Data, options: XMLParser.Options = .skipInvalidElements) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: data)
        let parser = XMLParser(options: options)
        return try parser.parseSVG(element)
    }
}
