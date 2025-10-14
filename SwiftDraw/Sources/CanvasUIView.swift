//
//  CanvasUIView.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 07/9/25.
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

#if canImport(UIKit) && !os(watchOS)
import UIKit
import SwiftUI

@available(iOS, deprecated: 15.0, message: "use SwiftUI.Canvas")
struct CanvasFallbackView: UIViewRepresentable {

    var svg: SVG
    var capInsets: EdgeInsets
    var resizingMode: SVGView.ResizingMode

    func makeUIView(context: Context) -> CanvasUIView {
        let uiView = CanvasUIView()
        uiView.isOpaque = false
        uiView.contentMode = .redraw
        return uiView
    }

    func updateUIView(_ uiView: CanvasUIView, context: Context) {
        uiView.svg = svg
        uiView.resizeMode = resizingMode
        uiView.capInsets = (capInsets.top, capInsets.leading, capInsets.bottom, capInsets.trailing)
        uiView.setNeedsDisplay()
    }
}

final class CanvasUIView: UIView {

    var svg: SVG?
    var resizeMode: SVGView.ResizingMode = .stretch
    var capInsets: (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) = (0, 0, 0, 0)

    override func draw(_ rect: CGRect) {
        guard let svg,
              let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.draw(
            svg,
            in: rect,
            capInsets: capInsets,
            byTiling: resizeMode == .tile
        )
    }
}

#endif
