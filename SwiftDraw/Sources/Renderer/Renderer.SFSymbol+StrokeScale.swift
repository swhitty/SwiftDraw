//
//  Renderer.SFSymbol+StrokeScale.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 22/4/26.
//  Copyright 2026 Simon Whitty
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
import Foundation

public extension SFSymbolRenderer {

    /// Multiplier applied to every stroke-width in a source SVG when generating
    /// an autoscaled weight variant. Accepts decimal (`0.5`) and percent (`50%`) syntax
    struct StrokeWidthScale: Equatable, Sendable {
        public let multiplier: Double

        public init(multiplier: Double) {
            self.multiplier = multiplier
        }

        public init?(rawValue: String) {
            let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasSuffix("%") {
                let body = trimmed.dropLast()
                guard let value = Double(body), value > 0 else { return nil }
                self.multiplier = value / 100.0
            } else {
                guard let value = Double(trimmed), value > 0 else { return nil }
                self.multiplier = value
            }
        }
    }
}

enum StrokeWidthScaler {

    /// Walks the SVG DOM and multiplies every stroke-width it finds (element attributes,
    /// inline styles, and stylesheet rules) by `scale`. Returns the number of values mutated
    @discardableResult
    static func scale(_ svg: DOM.SVG, by scale: SFSymbolRenderer.StrokeWidthScale) -> Int {
        var count = 0
        scaleAttributes(of: svg, by: scale, count: &count)
        scaleChildren(of: svg, by: scale, count: &count)
        scaleDefs(&svg.defs, by: scale, count: &count)
        scaleStyles(&svg.styles, by: scale, count: &count)
        return count
    }

    private static func scaleChildren(of container: any ContainerElement, by scale: SFSymbolRenderer.StrokeWidthScale, count: inout Int) {
        for child in container.childElements {
            scaleAttributes(of: child, by: scale, count: &count)
            if let nested = child as? any ContainerElement {
                scaleChildren(of: nested, by: scale, count: &count)
            }
        }
    }

    private static func scaleAttributes(of element: DOM.GraphicsElement, by scale: SFSymbolRenderer.StrokeWidthScale, count: inout Int) {
        if let value = element.attributes.strokeWidth {
            element.attributes.strokeWidth = multiply(value, by: scale)
            count += 1
        }
        if let value = element.style.strokeWidth {
            element.style.strokeWidth = multiply(value, by: scale)
            count += 1
        }
    }

    private static func scaleDefs(_ defs: inout DOM.SVG.Defs, by scale: SFSymbolRenderer.StrokeWidthScale, count: inout Int) {
        for clipPath in defs.clipPaths {
            scaleChildren(of: clipPath, by: scale, count: &count)
        }
        for mask in defs.masks {
            scaleAttributes(of: mask, by: scale, count: &count)
            scaleChildren(of: mask, by: scale, count: &count)
        }
        for pattern in defs.patterns {
            scaleChildren(of: pattern, by: scale, count: &count)
        }
        for element in defs.elements.values {
            scaleAttributes(of: element, by: scale, count: &count)
            if let container = element as? any ContainerElement {
                scaleChildren(of: container, by: scale, count: &count)
            }
        }
    }

    private static func scaleStyles(_ styles: inout [DOM.StyleSheet], by scale: SFSymbolRenderer.StrokeWidthScale, count: inout Int) {
        for sheetIndex in styles.indices {
            for selector in styles[sheetIndex].attributes.keys {
                if let value = styles[sheetIndex].attributes[selector]?.strokeWidth {
                    styles[sheetIndex].attributes[selector]?.strokeWidth = multiply(value, by: scale)
                    count += 1
                }
            }
        }
    }

    private static func multiply(_ value: DOM.Float, by scale: SFSymbolRenderer.StrokeWidthScale) -> DOM.Float {
        DOM.Float(Double(value) * scale.multiplier)
    }
}

