//
//  CodeRenderer.Path.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/4/17.
//  Copyright 2017 Simon Whitty
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

enum CodePath: Equatable {
    case ellipse(within: Builder.Rect)
    case rect(rect: Builder.Rect, radii: Builder.Size)
    case lines(between: [Builder.Point])
    case polygon(points: [Builder.Point])
    case path(from: Builder.Path)
    case compound(paths: [CodePath])
    
    static func ==(lhs: CodePath, rhs: CodePath) -> Bool {
        switch (lhs, rhs) {
        case (.ellipse(let lVal), .ellipse(let rVal)):
            return lVal == rVal
        case (.rect(let lVal), .rect(let rVal)):
            return lVal == rVal
        case (.lines(let lVal), .lines(let rVal)):
            return lVal == rVal
        case (.polygon(let lVal), .polygon(let rVal)):
            return lVal == rVal
        case (.path(let lVal), .path(let rVal)):
            return lVal == rVal
        case (.compound(let lVal), .compound(let rVal)):
            return lVal == rVal
        default:
            return false
        }
    }
}
