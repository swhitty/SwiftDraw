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
    class Layer: Equatable {
        var contents: [Contents] = []
        var opacity: Float?
        var transform: Transform?
        var clip: [Path] = []
        var mask: Layer?
        
        enum Contents: Equatable {
            case shape(Shape, StrokeAttributes, FillAttributes)
            case image(Image)
            case text(String, Point, TextAttributes)
            case layer(Layer)
            
            static func ==(lhs: Contents, rhs: Contents) -> Bool {
                switch (lhs, rhs) {
                case (.shape(let lval), .shape(let rval)):
                    return lval.0 == rval.0 && lval.1 == rval.1 && lval.2 == rval.2
                case (.image(let lval), .image(let rval)):
                    return lval == rval
                case (.text(let lval), .text(let rval)):
                    return lval.0 == rval.0 && lval.1 == rval.1 && lval.2 == rval.2
                case (.layer(let lval), .layer(let rval)):
                    return lval == rval
                default:
                    return false
                }
            }
        }
        
        static func ==(lhs: Layer, rhs: Layer) -> Bool {
            return lhs.contents == rhs.contents &&
                   lhs.opacity == rhs.opacity &&
                   lhs.transform == rhs.transform &&
                   lhs.clip == rhs.clip &&
                   lhs.mask == rhs.mask
        }
    }

    struct StrokeAttributes: Equatable {
        var color: Color
        var width: Float
        var cap: LineCap
        var join: LineJoin
        var miterLimit: Float
        
        static func ==(lhs: StrokeAttributes, rhs: StrokeAttributes) -> Bool {
            return lhs.color == rhs.color &&
                   lhs.width == rhs.width &&
                   lhs.cap == rhs.cap &&
                   lhs.join == rhs.join &&
                   lhs.miterLimit == rhs.miterLimit
        }
        
        static var normal: StrokeAttributes {
            return StrokeAttributes(color: .black,
                                    width: 1.0,
                                    cap: .butt,
                                    join: .bevel,
                                    miterLimit: 4.0)
        }
    }

    struct FillAttributes: Equatable {
        var color: Color
        var rule: FillRule
        
        static func ==(lhs: FillAttributes, rhs: FillAttributes) -> Bool {
            return lhs.color == rhs.color &&
                   lhs.rule == rhs.rule
        }
        
        static var normal: FillAttributes {
            return FillAttributes(color: .black, rule: .evenodd)
        }
    }
    
    struct TextAttributes: Equatable {
        var color: Color
        var fontName: String
        var size: Float
        
        static var normal: TextAttributes {
            return TextAttributes(color: .black, fontName: "Helvetica", size: 12.0)
        }
        
        static func ==(lhs: TextAttributes, rhs: TextAttributes) -> Bool {
            return lhs.color == rhs.color &&
                   lhs.fontName == rhs.fontName &&
                   lhs.size == rhs.size
        }
    }
}
