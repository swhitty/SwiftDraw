//
//  LayerTree.Pattern.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/3/19.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

extension LayerTree {

    final class Pattern: Hashable {

        var frame: LayerTree.Rect
        var contents: [LayerTree.Layer.Contents]

        init(frame: LayerTree.Rect) {
            self.frame = frame
            self.contents = []
        }

        func hash(into hasher: inout Hasher) {
            frame.hash(into: &hasher)
            contents.hash(into: &hasher)
        }

        static func == (lhs: LayerTree.Pattern, rhs: LayerTree.Pattern) -> Bool {
            return lhs.frame == rhs.frame && lhs.contents == rhs.contents
        }
    }
}
