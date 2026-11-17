//
//  DOM.PresentationAttributes.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/8/22.
//  Copyright 2022 Simon Whitty
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

package extension DOM {

    // PresentationAttributes cascade;
    // element.attributes --> .element() --> .class() ---> .id() ---> element.style ---> layerTree.state
    // (parsed documents: element.attributes --> matched rules --> element.style --> !important rules --> !important style)

    struct PresentationAttributes {
        package var opacity: DOM.Float?
        package var display: DOM.DisplayMode?
        package var visibility: DOM.Visibility?
        package var color: DOM.Color?

        package var stroke: DOM.Fill?
        package var strokeWidth: DOM.DashLength?
        package var strokeOpacity: DOM.Float?
        package var strokeLineCap: DOM.LineCap?
        package var strokeLineJoin: DOM.LineJoin?
        package var strokeDashArray: [DOM.DashLength]?
        package var strokeDashOffset: DOM.DashLength?

        package var fill: DOM.Fill?
        package var fillOpacity: DOM.Float?
        package var fillRule: DOM.FillRule?

        package var fontFamily: [DOM.FontFamily]?
        package var fontSize: FontSize?
        package var fontWeight: FontWeight?
        package var fontStyle: FontStyle?
        package var textAnchor: TextAnchor?
        package var dominantBaseline: TextBaseline?
        /// not inherited: the baseline of a `<tspan>` itself, when not its `dominant-baseline`
        package var alignmentBaseline: TextBaseline?
        package var baselineShift: BaselineShift?
        /// CSS `letter-spacing` and `word-spacing`; `normal` is a length of 0
        package var letterSpacing: DashLength?
        package var wordSpacing: DashLength?

        package var transform: [DOM.Transform]?
        package var transformOrigin: DOM.TransformOrigin?
        package var clipPath: DOM.URL?
        package var clipRule: DOM.FillRule?
        package var mask: DOM.URL?
        package var maskType: DOM.MaskType?
        /// inherited: gradients and masks use the value in effect on the `<linearGradient>`, `<radialGradient>` or `<mask>`
        package var colorInterpolation: DOM.ColorInterpolation?
        // url() references and filter functions in order; empty for `none`
        package var filter: [DOM.FilterValue]?
        package var overflow: DOM.Overflow?

        package var markerStart: DOM.URL?
        package var markerMid: DOM.URL?
        package var markerEnd: DOM.URL?
        package var paintOrder: DOM.PaintOrder?

        package var stopColor: DOM.Color?
        package var stopOpacity: DOM.Float?
    }

    static func presentationAttributes(
        for element: DOM.GraphicsElement,
        styles: [StyleSheet]
    ) -> PresentationAttributes {
        cascade(
            attributes: element.attributes,
            matched: element.matchedStyle,
            selectors: makeSelectors(for: element),
            style: element.style,
            importantStyle: element.importantStyle,
            styles: styles
        )
    }

    /// The cascade of a `<clipPath>` itself (SD8), in the same order as other elements.
    static func presentationAttributes(
        for clipPath: ClipPath,
        styles: [StyleSheet]
    ) -> PresentationAttributes {
        cascade(
            attributes: clipPath.attributes,
            matched: clipPath.matchedStyle,
            selectors: makeSelectors(elementName: "clipPath", class: clipPath.class, id: clipPath.id),
            style: clipPath.style,
            importantStyle: clipPath.importantStyle,
            styles: styles
        )
    }

    private static func cascade(
        attributes: PresentationAttributes,
        matched: StyleSheet.Matched?,
        selectors: @autoclosure () -> [StyleSheet.Selector],
        style: PresentationAttributes,
        importantStyle: PresentationAttributes,
        styles: [StyleSheet]
    ) -> PresentationAttributes {
        var attributes = attributes

        if let matched {
            // parsed documents: every selector form, by specificity then source order (CSS Cascade 3 §6)
            attributes = attributes.applyingAttributes(matched.attributes)
        } else {
            // elements built in code: element name, class and id rules
            for selector in selectors() {
                let new = makeAttributes(for: selector, styles: styles)
                attributes = attributes.applyingAttributes(new)
            }
        }

        attributes = attributes.applyingAttributes(style)

        if let matched {
            // `!important` stylesheet declarations override style=""
            attributes = attributes.applyingAttributes(matched.importantAttributes)
        }

        // and `!important` in style="" overrides them (CSS Cascade 3 §6.1)
        return attributes.applyingAttributes(importantStyle)
    }

    static func makeSelectors(for element: DOM.GraphicsElement) -> [StyleSheet.Selector] {
        makeSelectors(elementName: element.elementName, class: element.class, id: element.id)
    }

    static func makeSelectors(elementName: String?, class: String?, id: String?) -> [StyleSheet.Selector] {
        var selectors = [StyleSheet.Selector]()

        if let elementName {
            selectors.append(.element(elementName))
        }

        if let classes = `class`?.split(separator: " ") {
            selectors.append(
                contentsOf:
                    classes
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .map(StyleSheet.Selector.class)
            )
        }

        if let id {
            selectors.append(.id(id.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return selectors
    }

    static func makeAttributes(for selector: StyleSheet.Selector, styles: [StyleSheet]) -> PresentationAttributes {
        var attributes = PresentationAttributes()

        for sheet in styles {
            if let att = sheet.attributes[selector] {
                attributes = attributes.applyingAttributes(att)
            }
        }

        return attributes
    }
}

extension DOM.PresentationAttributes {

    func applyingAttributes(_ att: Self) -> Self {
        var merged = DOM.PresentationAttributes()

        merged.opacity = att.opacity ?? opacity
        merged.display = att.display ?? display
        merged.visibility = att.visibility ?? visibility
        merged.color = att.color ?? color

        merged.stroke = att.stroke ?? stroke
        merged.strokeWidth = att.strokeWidth ?? strokeWidth
        merged.strokeOpacity = att.strokeOpacity ?? strokeOpacity
        merged.strokeLineCap = att.strokeLineCap ?? strokeLineCap
        merged.strokeLineJoin = att.strokeLineJoin ?? strokeLineJoin
        merged.strokeDashArray = att.strokeDashArray ?? strokeDashArray
        merged.strokeDashOffset = att.strokeDashOffset ?? strokeDashOffset

        merged.fill = att.fill ?? fill
        merged.fillOpacity = att.fillOpacity ?? fillOpacity
        merged.fillRule = att.fillRule ?? fillRule

        merged.fontFamily = att.fontFamily ?? fontFamily
        merged.fontSize = att.fontSize ?? fontSize
        merged.fontWeight = att.fontWeight ?? fontWeight
        merged.fontStyle = att.fontStyle ?? fontStyle
        merged.textAnchor = att.textAnchor ?? textAnchor
        merged.dominantBaseline = att.dominantBaseline ?? dominantBaseline
        merged.alignmentBaseline = att.alignmentBaseline ?? alignmentBaseline
        merged.baselineShift = att.baselineShift ?? baselineShift
        merged.letterSpacing = att.letterSpacing ?? letterSpacing
        merged.wordSpacing = att.wordSpacing ?? wordSpacing

        merged.transform = att.transform ?? transform
        merged.transformOrigin = att.transformOrigin ?? transformOrigin
        merged.clipPath = att.clipPath ?? clipPath
        merged.clipRule = att.clipRule ?? clipRule
        merged.mask = att.mask ?? mask
        merged.maskType = att.maskType ?? maskType
        merged.colorInterpolation = att.colorInterpolation ?? colorInterpolation
        merged.filter = att.filter ?? filter
        merged.overflow = att.overflow ?? overflow

        merged.markerStart = att.markerStart ?? markerStart
        merged.markerMid = att.markerMid ?? markerMid
        merged.markerEnd = att.markerEnd ?? markerEnd
        merged.paintOrder = att.paintOrder ?? paintOrder

        merged.stopColor = att.stopColor ?? stopColor
        merged.stopOpacity = att.stopOpacity ?? stopOpacity

        return merged
    }
}

extension DOM.GraphicsElement {

    var elementName: String? {
        switch self {
        case is DOM.Line:
            return "line"
        case is DOM.Circle:
            return "circle"
        case is DOM.Ellipse:
            return "ellipse"
        case is DOM.Rect:
            return "rect"
        case is DOM.Polyline:
            return "polyline"
        case is DOM.Polygon:
            return "polygon"
        case is DOM.Path:
            return "path"
        case is DOM.Text:
            return "text"
        case is DOM.Image:
            return "image"
        case is DOM.Group:
            return "g"
        case is DOM.Anchor:
            return "a"
        case is DOM.SVG:
            return "svg"
        case is DOM.Mask:
            return "mask"
        case is DOM.Symbol:
            return "symbol"
        case is DOM.Marker:
            return "marker"
        default:
            return nil
        }
    }
}
