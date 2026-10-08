//
//  LayerTree.Filter.swift
//  SwiftDraw
//
//  Created by Misoservices on 8/10/26.
//  Copyright 2026 Misoservices. Altered version of SwiftDraw by Simon Whitty.
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


import SwiftDrawDOM

extension LayerTree {

    // The <filter> element's region and units, resolved against the layer when commands are generated.
    // nil values take the spec defaults: -10% / -10% / 120% / 120%.
    struct FilterRegion: Hashable {
        var x: Float?
        var y: Float?
        var width: Float?
        var height: Float?
        var units: FilterUnits = .objectBoundingBox
        var primitiveUnits: FilterUnits = .userSpaceOnUse
    }

    enum FilterUnits: Hashable {
        case userSpaceOnUse
        case objectBoundingBox
    }

    // A filter resolved into the user space of the layer it applies to.
    // Renderers draw the layer contents offscreen, apply the effects in order, then composite the result
    // clipped to region.
    struct FilterLayer: Hashable {
        var region: Rect
        var effects: [Filter]
    }
}

extension LayerTree.Filter {

    var isSupported: Bool {
        switch self {
        case .gaussianBlur(_, _):
            return true
        case .unsupported:
            return false
        }
    }
}
