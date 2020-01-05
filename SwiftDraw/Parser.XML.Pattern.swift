//
//  Parser.XML.Pattern.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/3/19.
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
  
  func parsePattern(_ att: AttributeParser) throws -> DOM.Pattern {
    
    let id: String = try att.parseString("id")
    let width: DOM.Coordinate = try att.parseCoordinate("width")
    let height: DOM.Coordinate = try att.parseCoordinate("height")
    
    var pattern = DOM.Pattern(id: id, width: width, height: height)
    pattern.x = try att.parseCoordinate("x")
    pattern.y = try att.parseCoordinate("y")
    
    pattern.patternUnits = try att.parseRaw("patternUnits")
    pattern.patternContentUnits = try att.parseRaw("patternContentUnits")
    
    return pattern
  }
  
}
