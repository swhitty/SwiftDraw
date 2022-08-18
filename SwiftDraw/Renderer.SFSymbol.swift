//
//  Renderer.SFSymbol.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/8/22.
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


public final class SFSymbolRenderer {

    func makeDOM(for layer: LayerTree.Layer) throws -> DOM.SVG {
        throw Error.invalid
    }

    enum Error: Swift.Error {
        case invalid
    }
}

public extension SFSymbolRenderer {

    static func render(fileURL: URL, options: Image.Options) throws -> String {
        let svg = try DOM.SVG.parse(fileURL: fileURL)
        let element = try XML.Formatter.SVG().makeElement(from: svg)
        let formatter = XML.Formatter(spaces: 2)
        return formatter.encodeRootElement(element)
    }
}
