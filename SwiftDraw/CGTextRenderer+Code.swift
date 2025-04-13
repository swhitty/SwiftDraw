//
//  Image+CGText.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/6/21.
//  Copyright 2021 Simon Whitty
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

public extension CGTextRenderer {

    typealias Size = (width: Int, height: Int)

    static func render(named name: String,
                       in bundle: Bundle = Bundle.main,
                       size: Size? = nil,
                       options: SVG.Options,
                       api: CGTextRenderer.API,
                       precision: Int) throws -> String {
        guard let url = bundle.url(forResource: name, withExtension: nil) else {
            throw Error("File not found.")
        }
        return try render(fileURL: url, size: size, options: options, api: api, precision: precision)
    }

    static func render(fileURL: URL, size: Size? = nil, options: SVG.Options, api: CGTextRenderer.API, precision: Int) throws -> String {
        let svg = try DOM.SVG.parse(fileURL: fileURL)
        let size = makeSize(svg: svg, size: size)
        let identifier = fileURL.lastPathComponent
            .replacingOccurrences(of: ".\(fileURL.pathExtension)", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
            .replacingOccurrences(of: " ", with: "")

        return cgCodeText(api: api,
                          name: identifier,
                          svg: svg,
                          size: size,
                          options: options,
                          precision: precision)
    }

    static func render(data: Data, options: SVG.Options, api: CGTextRenderer.API, precision: Int) throws -> String {
        let svg = try DOM.SVG.parse(data: data)
        let size = makeSize(svg: svg, size: nil)
        return cgCodeText(api: api,
                          name: "Image",
                          svg: svg,
                          size: size,
                          options: options,
                          precision: precision)
    }

    static func renderPath(from svgPath: String) throws -> String {
        let domPath = try XMLParser().parsePath(from: svgPath)
        let layerPath = try LayerTree.Builder.createPath(from: domPath)
        let formatter = CoordinateFormatter(delimeter: .commaSpace, precision: .capped(max: 3))
        return renderPath(from: layerPath, formatter: formatter)
    }

    private static func makeSize(svg: DOM.SVG, size: Size?) -> LayerTree.Size {
        guard let size = size else {
            return LayerTree.Size(svg.width, svg.height)
        }
        return LayerTree.Size(LayerTree.Float(size.width), LayerTree.Float(size.height))
    }

    private static func cgCodeText(api: CGTextRenderer.API,
                                   name: String,
                                   svg: DOM.SVG,
                                   size: LayerTree.Size,
                                   options: SVG.Options,
                                   precision: Int) -> String {
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let commandSize = LayerTree.Size(svg.width, svg.height)

        let formatter = CoordinateFormatter(delimeter: .commaSpace,
                                            precision: .capped(max: precision))

        let generator = LayerTree.CommandGenerator(provider: CGTextProvider(formatter: formatter),
                                                   size: commandSize,
                                                   options: options)

        let optimizer = LayerTree.CommandOptimizer<CGTextTypes>(options: [.skipRedundantState, .skipInitialSaveState])
        let commands = optimizer.optimizeCommands(
            generator.renderCommands(for: layer, colorConverter: .default)
        )

        let renderer = CGTextRenderer(api: api,
                                      name: name,
                                      size: size,
                                      commandSize: commandSize,
                                      formatter: formatter)
        renderer.perform(commands)

        return renderer.makeText()
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}
