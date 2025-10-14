//
//  SVGView.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/2/25.
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

#if canImport(SwiftUI)
public import SwiftUI

public struct SVGView: View {

    public init(_ name: String, bundle: Bundle = .main) {
        self.svg = SVG(named: name, in: bundle)
    }

    public init(svg: SVG) {
        self.svg = svg
    }

    private let svg: SVG?
    private var resizable: (capInsets: EdgeInsets, mode: ResizingMode)?

    public var body: some View {
        if let svg {
            if let resizable {
                SVGView.makeCanvas(svg: svg, capInsets: resizable.capInsets, resizingMode: resizable.mode)
                    .frame(idealWidth: svg.size.width, idealHeight: svg.size.height)
            } else {
                SVGView.makeCanvas(svg: svg, resizingMode: .stretch)
                    .frame(width: svg.size.width, height: svg.size.height)
            }
        }
    }

    public enum ResizingMode: Sendable, Hashable {
        /// A mode to repeat the image at its original size, as many
        /// times as necessary to fill the available space.
        case tile

        /// A mode to enlarge or reduce the size of an image so that it
        /// fills the available space.
        case stretch
    }

    /// Sets the mode by which SwiftUI resizes an SVG to fit its space.
    /// - Parameters:
    ///   - capInsets: Inset values that indicate a portion of the image that
    ///   SwiftUI doesn't resize.
    ///   - resizingMode: The mode by which SwiftUI resizes the image.
    /// - Returns: An SVGView, with the new resizing behavior set.
    public func resizable(
        capInsets: EdgeInsets = EdgeInsets(),
        resizingMode: ResizingMode = .stretch
    ) -> Self {
        var copy = self
        copy.resizable = (capInsets, resizingMode)
        return copy
    }

    @ViewBuilder
    private static func makeCanvas(svg: SVG, capInsets: EdgeInsets = .init(), resizingMode: ResizingMode) -> some View {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            Canvas(
                opaque: false,
                colorMode: .linear,
                rendersAsynchronously: false
            ) { ctx, size in
                ctx.draw(
                    svg,
                    in: CGRect(origin: .zero, size: size),
                    capInsets: capInsets,
                    byTiling: resizingMode == .tile
                )
            }
        } else {
            #if !os(watchOS)
            CanvasFallbackView(
                svg: svg,
                capInsets: capInsets,
                resizingMode: resizingMode
            )
            #endif
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension GraphicsContext {

    func draw(_ svg: SVG, in rect: CGRect? = nil)  {
        withCGContext {
            $0.draw(svg, in: rect)
        }
    }

    func draw(_ svg: SVG, in rect: CGRect, capInsets: EdgeInsets, byTiling: Bool = false)  {
        withCGContext {
            $0.draw(
                svg,
                in: rect,
                capInsets: (capInsets.top, capInsets.leading, capInsets.bottom, capInsets.trailing),
                byTiling: byTiling
            )
        }
    }
}

#if DEBUG

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
#Preview {
    SVGView(svg: .circle)

    SVGView(svg: .circle)
        .resizable(resizingMode: .stretch)

    SVGView(svg: .circle)
        .resizable(resizingMode: .tile)
}

private extension SVG {

    static var circle: SVG {
        SVG(xml: """
        <svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="100" height="100">
          <circle cx="50" cy="50" r="50" fill="orange" />
        </svg>
        """)!
    }
}
#endif

#endif
