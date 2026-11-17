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
    private var renderingMode: TemplateRenderingMode = .original

    // filled in the background after the first draw deferred filters; each fill redraws
    @State private var filterFills = 0

    private var didFillFilters: @Sendable () -> Void {
        let fills = $filterFills
        return {
            Task { @MainActor in
                fills.wrappedValue += 1
            }
        }
    }

    public var body: some View {
        if let svg {
            if let resizable {
                SVGView.makeCanvas(
                    svg: svg,
                    capInsets: resizable.capInsets,
                    resizingMode: resizable.mode,
                    renderingMode: renderingMode,
                    filterFills: filterFills,
                    didFillFilters: didFillFilters
                )
                .frame(idealWidth: svg.size.width, idealHeight: svg.size.height)
            } else {
                SVGView.makeCanvas(
                    svg: svg,
                    resizingMode: .stretch,
                    renderingMode: renderingMode,
                    filterFills: filterFills,
                    didFillFilters: didFillFilters
                )
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

    public enum TemplateRenderingMode: Sendable, Hashable {
        /// A mode that renders all non-transparent pixels as the foreground style.
        case template

        /// A mode that renders pixels of svg as-is.
        case original
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

    /// Sets the mode by which SwiftUI renders the SVG.
    /// - `.original` renders the SVG as-is
    /// - `.template` renders all non-transparent pixels as the foreground style.
    public func renderingMode(_ renderingMode: TemplateRenderingMode) -> Self {
        var copy = self
        copy.renderingMode = renderingMode
        return copy
    }

    @ViewBuilder
    private static func makeCanvas(
        svg: SVG,
        capInsets: EdgeInsets = .init(),
        resizingMode: ResizingMode,
        renderingMode: TemplateRenderingMode,
        filterFills: Int,
        didFillFilters: @escaping @Sendable () -> Void
    ) -> some View {
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
                    byTiling: resizingMode == .tile,
                    renderingMode: renderingMode,
                    // Filtered results are kept between redraws, and for views showing it again.
                    // A first draw does not evaluate filters missing from them: those are drawn unfiltered
                    // while the cache is filled in the background, then drawn again.
                    filters: CanvasFilters(
                        cache: .shared(for: svg, size: size),
                        defersMisses: filterFills == 0,
                        onDeferred: { fill in
                            Task {
                                await fill.perform()
                                didFillFilters()
                            }
                        }
                    )
                )
            }
        } else {
            #if !os(watchOS)
            switch renderingMode {
            case .original:
                CanvasFallbackView(
                    svg: svg,
                    capInsets: capInsets,
                    resizingMode: resizingMode
                )
            case .template:
                Rectangle()
                    .fill(ForegroundStyle())
                    .mask(
                        CanvasFallbackView(
                            svg: svg,
                            capInsets: capInsets,
                            resizingMode: resizingMode
                        )
                    )
            }
            #endif
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension GraphicsContext {

    func draw(_ svg: SVG, in rect: CGRect? = nil) {
        withCGContext {
            $0.draw(svg, in: rect)
        }
    }

    func draw(_ svg: SVG, in rect: CGRect, capInsets: EdgeInsets, byTiling: Bool = false) {
        draw(svg, in: rect, capInsets: capInsets, byTiling: byTiling, filters: nil)
    }

    mutating func draw(
        _ svg: SVG,
        in rect: CGRect,
        capInsets: EdgeInsets,
        byTiling: Bool = false,
        renderingMode: SVGView.TemplateRenderingMode
    ) {
        draw(svg, in: rect, capInsets: capInsets, byTiling: byTiling, renderingMode: renderingMode, filters: nil)
    }
}

// How a Canvas draw uses a filter layer cache
struct CanvasFilters {
    var cache: CGFilterLayerCache
    // filter layers missing from the cache are drawn unfiltered, then filled in the background by onDeferred
    var defersMisses: Bool
    var onDeferred: @Sendable (CGFilterLayerFill) -> Void
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext {

    func draw(_ svg: SVG, in rect: CGRect, capInsets: EdgeInsets, byTiling: Bool, filters: CanvasFilters?) {
        // a Canvas context is not a bitmap: its CTM need not carry the display scale tiles are rasterized at
        let scale = environment.displayScale
        let insets = (capInsets.top, capInsets.leading, capInsets.bottom, capInsets.trailing)
        let draw: @Sendable (CGContext, CGFilterLayerDraw?) -> Void = { context, filters in
            context.draw(svg, in: rect, capInsets: insets, byTiling: byTiling, tileScale: scale, filters: filters)
        }
        withCGContext { context in
            guard let filters else {
                draw(context, nil)
                return
            }
            // a fill replays this draw in a bitmap with the context's device space and clip, as they are now
            let fill =
                filters.defersMisses ? CGFilterLayerFill(context: context, cache: filters.cache, draw: draw) : nil
            let layers = CGFilterLayerDraw(filters.cache, defersMisses: fill != nil)
            draw(context, layers)
            if layers.didDefer, let fill {
                filters.onDeferred(fill)
            }
        }
    }

    mutating func draw(
        _ svg: SVG,
        in rect: CGRect,
        capInsets: EdgeInsets,
        byTiling: Bool,
        renderingMode: SVGView.TemplateRenderingMode,
        filters: CanvasFilters?
    ) {
        switch renderingMode {
        case .original:
            draw(svg, in: rect, capInsets: capInsets, byTiling: byTiling, filters: filters)
        case .template:
            if Self.requiresClipToLayerWorkaround(svg, in: rect, byTiling: byTiling) {
                clipToLayer { mask in
                    mask.scaleBy(x: rect.size.width / svg.size.width, y: rect.size.height / svg.size.height)
                    mask.draw(
                        svg,
                        in: CGRect(origin: .zero, size: svg.size),
                        capInsets: capInsets,
                        byTiling: false,
                        filters: filters
                    )
                }
            } else {
                clipToLayer { mask in
                    mask.draw(svg, in: rect, capInsets: capInsets, byTiling: byTiling, filters: filters)
                }
            }
            fill(Path(rect), with: .foreground)
        }
    }

    private static func requiresClipToLayerWorkaround(
        _ svg: SVG,
        in rect: CGRect,
        byTiling: Bool
    ) -> Bool {
        if #available(iOS 27.0,
        macOS 27.0,
        tvOS 27.0,
        watchOS 27.0,
        visionOS 27.0,
        *) {
            return false
        } else {
            // clipToLayer has a bug on OS 26 and earlier with non uniform scale
            let scaleX = rect.size.width / svg.size.width
            let scaleY = rect.size.height / svg.size.height
            return byTiling == false && scaleX != scaleY
        }
    }
}

#if DEBUG

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
#Preview {
    SVGView(svg: .circle)

    SVGView(svg: .circleStroke)
        .resizable(resizingMode: .stretch)
        .renderingMode(.template)
        .foregroundStyle(Color.pink)

    SVGView(svg: .circle)
        .resizable(resizingMode: .tile)
}

private extension SVG {

    static var circle: SVG {
        SVG(
            xml: """
                <svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <circle cx="50" cy="50" r="50" fill="orange" />
                </svg>
                """
        )!
    }

    static var circleStroke: SVG {
        SVG(
            xml: """
                <svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="100" height="100">
                  <circle cx="50" cy="50" r="45" stroke-width="4" stroke="black" fill="none" />
                </svg>
                """
        )!
    }
}
#endif

#endif
