//
//  Image.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 24/5/17.
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

#if canImport(CoreGraphics)
import CoreGraphics

@objc(SVGImage)
public final class SVG: NSObject {
    public let size: CGSize

    //An Image is simply an array of CoreGraphics draw commands
    //see: Renderer.swift
    let commands: [RendererCommand<CGTypes>]

    init(dom: DOM.SVG, options: Options) {
        self.size = CGSize(width: dom.width, height: dom.height)

        //To create the draw commands;
        // - XML is parsed into DOM.SVG
        // - DOM.SVG is converted into a LayerTree
        // - LayerTree is converted into RenderCommands
        // - RenderCommands are performed by Renderer (drawn to CGContext)
        let layer = LayerTree.Builder(svg: dom).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: CGProvider(),
                                                   size: LayerTree.Size(dom.width, dom.height),
                                                   options: options)

        let optimizer = LayerTree.CommandOptimizer<CGTypes>()
        commands = optimizer.optimizeCommands(
            generator.renderCommands(for: layer)
        )
    }

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let hideUnsupportedFilters = Options(rawValue: 1 << 0)

        public static let `default`: Options = []
    }
}

@available(*, unavailable, renamed: "SVG")
public enum Image { }

#else

public final class SVG: NSObject {
    public let size: CGSize

    init(dom: DOM.SVG, options: Options) {
        size = CGSize(width: dom.width, height: dom.height)
    }

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let hideUnsupportedFilters = Options(rawValue: 1 << 0)

        public static let `default`: Options = []
    }
}

public extension SVG {

    func pngData(size: CGSize? = nil, scale: CGFloat = 1) -> Data? {
        return nil
    }

    func jpegData(size: CGSize? = nil, scale: CGFloat = 1, compressionQuality quality: CGFloat = 1) -> Data? {
        return nil
    }

    func pdfData(size: CGSize? = nil) -> Data? {
        return nil
    }

    static func pdfData(fileURL url: URL, size: CGSize? = nil) throws -> Data {
        throw DOM.Error.missing("not implemented")
    }
}
#endif

extension DOM.SVG {

    static func parse(fileURL url: URL, options: XMLParser.Options = .skipInvalidElements) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(contentsOf: url)
        let parser = XMLParser(options: options, filename: url.lastPathComponent)
        return try parser.parseSVG(element)
    }

    static func parse(data: Data, options: XMLParser.Options = .skipInvalidElements) throws -> DOM.SVG {
        let element = try XML.SAXParser.parse(data: data)
        let parser = XMLParser(options: options)
        return try parser.parseSVG(element)
    }
}

public extension SVG {

    convenience init?(fileURL url: URL, options: SVG.Options = .default) {
        do {
            let svg = try DOM.SVG.parse(fileURL: url)
            self.init(dom: svg, options: options)
        } catch {
            XMLParser.logParsingError(for: error, filename: url.lastPathComponent, parsing: nil)
            return nil
        }
    }

    convenience init?(named name: String, in bundle: Bundle = Bundle.main, options: SVG.Options = .default) {
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            return nil
        }

        self.init(fileURL: url, options: options)
    }

    convenience init?(data: Data, options: SVG.Options = .default) {
        guard let svg = try? DOM.SVG.parse(data: data) else {
            return nil
        }

        self.init(dom: svg, options: options)
    }


    struct Insets: Equatable {
        public var top: CGFloat
        public var left: CGFloat
        public var bottom: CGFloat
        public var right: CGFloat

        public init(
            top: CGFloat = 0,
            left: CGFloat = 0, 
            bottom: CGFloat = 0,
            right: CGFloat = 0
        ) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }

        public static let zero = Insets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
