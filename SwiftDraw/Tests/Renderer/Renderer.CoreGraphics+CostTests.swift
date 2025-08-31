//
//  Renderer.CoreGraphics+CostTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/8/25.
//  Copyright 2025 WhileLoop Pty Ltd. All rights reserved.
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

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
@testable import SwiftDraw
import SwiftDrawDOM
import Testing

struct RendererCoreGraphicsCostTests {

    @Test
    func duplicatePathInstancesRemoved() throws {
        let source = try SVG.fromXML(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <clipPath id="cp1">
                <rect width="30" height="30" />
            </clipPath>
            <rect width="30" height="30" fill="red" stroke="blue" />
            <rect width="30" height="30" fill="pink" stroke="yellow" clip-path="url(#cp1)"/>
        </svg>
        """#)

        let uniquePaths = Set(source.commands.allPaths.map(ObjectIdentifier.init))
        #expect(uniquePaths.count == 1)
    }

    @Test
    func duplicateImageInstancesRemoved() throws {
        let source = try SVG.fromXML(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <image id="dot" width="6" height="6" xlink:href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" />
            <image id="dot" width="6" height="6" xlink:href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" />
        </svg>
        """#)

        let uniqueImages = Set(source.commands.allImages.map(ObjectIdentifier.init))
        #expect(uniqueImages.count == 1)
    }

    @Test
    func pathEstimatedCost() throws {
        let source = try SVG.fromXML(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <rect width="30" height="30" fill="red" stroke="blue" />
        </svg>
        """#)

        #expect(source.commands.allPaths[0].estimatedCost == 168)
        #expect(source.commands.estimatedCost == 232)
    }

    @Test
    func imageEstimatedCost() throws {
        let source = try SVG.fromXML(#"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="64" height="64" version="1.1" xmlns="http://www.w3.org/2000/svg">
            <image id="dot" width="6" height="6" xlink:href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" />
        </svg>
        """#)

        #expect(source.commands.allImages[0].estimatedCost == 100)
        #expect(source.commands.estimatedCost == 108)
    }

    @Test
    func shapesEstimatedCost() throws {
        let image = try #require(SVG(named: "shapes.svg", in: .test))
        #expect(image.commands.estimatedCost == 19220)
    }
}

extension SVG {
    static func fromXML(_ text: String, filename: String = #file) throws -> SVG {
        let dom = try DOM.SVG.parse(data: text.data(using: .utf8)!)
        return SVG(dom: dom, options: .default)
    }
}
#endif
