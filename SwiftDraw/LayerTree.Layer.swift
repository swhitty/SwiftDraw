//
//  LayerTree.Layer.swift
//  SwiftDraw
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

extension LayerTree {
    final class Layer: Hashable {
        var `class`: String? = nil
        var contents: [Contents] = []
        var opacity: Float = 1.0
        var transform: [Transform] = []
        var clip: [ClipShape] = []
        var clipRule: FillRule?
        var mask: Layer?
        var filters: [Filter] = []

        enum Contents: Hashable {
            case shape(Shape, StrokeAttributes, FillAttributes)
            case image(Image)
            case text(String, Point, TextAttributes)
            case layer(Layer)
        }

        func appendContents(_ contents: Contents) {
            switch contents {
            case .layer(let l):
                guard l.contents.isEmpty == false else { return }

                //if layer is simple, we can ignore all other properties
                if let simple = l.simpleContents {
                    self.contents.append(simple)
                } else {
                    self.contents.append(.layer(l))
                }
            default:
                self.contents.append(contents)
            }
        }

        var simpleContents: Contents? {
            guard self.contents.count == 1,
                  let first = self.contents.first,
                  opacity == 1.0,
                  transform == [],
                  clip == [],
                  mask == nil,
                  filters == [] else { return nil }

            return first
        }

        func hash(into hasher: inout Hasher) {
            `class`.hash(into: &hasher)
            opacity.hash(into: &hasher)
            transform.hash(into: &hasher)
            clip.hash(into: &hasher)
            mask.hash(into: &hasher)
            filters.hash(into: &hasher)
        }

        static func ==(lhs: Layer, rhs: Layer) -> Bool {
            return lhs.class == rhs.class &&
            lhs.contents == rhs.contents &&
            lhs.opacity == rhs.opacity &&
            lhs.transform == rhs.transform &&
            lhs.clip == rhs.clip &&
            lhs.clipRule == rhs.clipRule &&
            lhs.mask == rhs.mask &&
            lhs.filters == rhs.filters
        }
    }

    struct StrokeAttributes: Hashable {
        var color: Stroke
        var width: Float
        var cap: LineCap
        var join: LineJoin
        var miterLimit: Float

        enum Stroke: Hashable {
            case color(Color)
            case linearGradient(LinearGradient)
            case radialGradient(RadialGradient)

            static let none = Stroke.color(.none)
        }
    }

    struct FillAttributes: Hashable {
        var fill: Fill = .color(.none)
        var opacity: Float = 1.0
        var rule: FillRule

        init(color: Color, rule: FillRule) {
            self.fill = .color(color)
            self.rule = rule
        }

        init(pattern: Pattern, rule: FillRule, opacity: Float) {
            self.fill = .pattern(pattern)
            self.rule = rule
            self.opacity = opacity
        }

        init(linear gradient: LinearGradient, rule: FillRule, opacity: Float) {
            self.fill = .linearGradient(gradient)
            self.rule = rule
            self.opacity = opacity
        }

        init(radial gradient: RadialGradient, rule: FillRule, opacity: Float) {
            self.fill = .radialGradient(gradient)
            self.rule = rule
            self.opacity = opacity
        }
        
        enum Fill: Hashable {
            case color(Color)
            case pattern(Pattern)
            case linearGradient(LinearGradient)
            case radialGradient(RadialGradient)

            static let none = Fill.color(.none)
        }
    }

    struct TextAttributes: Hashable {
        var color: Color
        var fontName: String
        var size: Float
        var anchor: DOM.TextAnchor
    }
}
