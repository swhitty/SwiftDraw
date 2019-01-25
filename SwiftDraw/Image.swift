//
//  Image.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/5/17.
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

import Foundation

#if canImport(CoreGraphics)

@objc(SVGImage)
public final class Image: NSObject {
    public let size: CGSize
    
    //An Image is simply an array of CoreGraphics draw commands
    //see: Renderer.swift
    let commands: [RendererCommand<CGTypes>]

    init(svg: DOM.SVG) {
        size = CGSize(width: svg.width, height: svg.height)

        //To create the draw commands;
        // - XML is parsed into DOM.SVG
        // - DOM.SVG is converted into a LayerTree
        // - LayerTree is converted into RenderCommands
        // - RenderCommands are performed by Renderer (drawn to CGContext)
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: CGProvider())
        commands = generator.renderCommands(for: layer)
    }
}
#else

public final class Image: NSObject {
    public let size: CGSize

    init(svg: DOM.SVG) {
        size = CGSize(width: svg.width, height: svg.height)
    }

    public func pngData(size: CGSize? = nil, scale: CGFloat = 1) -> Data? {
        return nil
    }

    public func jpegData(size: CGSize? = nil, scale: CGFloat = 1, compressionQuality quality: CGFloat = 1) -> Data? {
        return nil
    }

    public func pdfData(size: CGSize? = nil) -> Data? {
        return nil
    }
}
#endif

public extension Image {

    convenience init?(fileURL url: URL) {
        let parser = XMLParser(options: [.skipInvalidElements])
        guard let element = try? XML.SAXParser.parse(contentsOf: url),
            let svg = try? parser.parseSVG(element) else {
                return nil
        }

        self.init(svg: svg)
    }

    convenience init?(named name: String, in bundle: Bundle = Bundle.main) {
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            return nil
        }

        self.init(fileURL: url)
    }
}
