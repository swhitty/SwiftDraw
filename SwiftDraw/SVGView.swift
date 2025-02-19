//
//  SVGView.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/2/25.
//  Copyright 2019 Simon Whitty
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

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SVGView: View {

    public init(_ name: String, bundle: Bundle = .main) {
        self.svg = SVG(named: name, in: bundle)
    }

    public init(svg: SVG) {
        self.svg = svg
    }

    private let svg: SVG?

    public var body: some View {
        if let svg {
            Canvas(
                 opaque: false,
                 colorMode: .linear,
                 rendersAsynchronously: false
             ) { ctx, size in
                 ctx.draw(svg, in: CGRect(origin: .zero, size: size))
             }
             .frame(idealWidth: svg.size.width, idealHeight: svg.size.height)
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension GraphicsContext {

    func draw(_ image: SVG, in rect: CGRect? = nil)  {
        withCGContext {
            $0.draw(image, in: rect)
        }
    }
}
#endif
