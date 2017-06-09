//
//  LayerTree.Builder.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 4/6/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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

// Convert a DOM.Svg into a layer tree

extension LayerTree {
    
    struct Builder {
        
        static func createLayer(from element: DOM.Svg) -> Layer {
            let l = createLayer(from: element, with: State())
    
            if let viewBox = element.viewBox {
                l.transform = createTransform(for: viewBox,
                                              width: element.width,
                                              height: element.height)
            } else {
                l.transform = .identity
            }
     
            return l
        }
        
        static func createLayer(from element: DOM.GraphicsElement, with children: [DOM.GraphicsElement], inheriting state: State) -> Layer {
            let l = Layer()
            
            let newState = createState(for: element, inheriting: state)
            
            l.transform = createTransform(concatenating: element.transform ?? [])
            l.contents = createLayers(for: children, inheriting: newState).map{ .layer($0) }
            
            return l
        }
        
        static func createTransform(for viewBox: DOM.Svg.ViewBox, width: DOM.Length, height: DOM.Length) -> LayerTree.Transform {
            
            let sx = LayerTree.Float(width) / viewBox.width
            let sy = LayerTree.Float(height) / viewBox.height
            return LayerTree.Transform(a: sx, b: 0.0, c: 0.0, d: sy, tx: -viewBox.x * sx, ty: -viewBox.y * sy)
        }
        
        
        static func createLayers(for elements: [DOM.GraphicsElement], inheriting state: State) -> [Layer] {
            var layers = Array<Layer>()
            for element in elements {
                layers.append(createLayer(from: element, with: state))
            }
            return layers
        }
        
        static func createLayer(from element: DOM.GraphicsElement, with state: State) -> Layer {
            let l = Layer()
            
            let newState = createState(for: element, inheriting: state)
            
            l.transform = createTransform(concatenating: element.transform ?? [])
            l.contents = createContents(from: element, with: newState).map{ [$0] } ?? []
            
            return l
        }
        
        static func createContents(from element: DOM.GraphicsElement, with state: State) -> Layer.Contents? {
            if let shape = createShape(from: element) {
                let stroke = createStrokeAttributes(with: state)
                let fill = createFillAttributes(with: state)
                return .shape(shape, stroke, fill)
            } else if let text = element as? DOM.Text {
                let point = Point(text.x ?? 0, text.y ?? 0)
                var att = createTextAttributes(with: state)
                att.fontName = text.fontFamily ?? att.fontName
                att.size = text.fontSize ?? att.size
                return .text(text.value, point, att)
            } else if let container = element as? ContainerElement {
                return .layer(createLayer(from: element, with: container.childElements, inheriting: state))
            }
            return nil
        }
        
        static func createShape(from element: DOM.GraphicsElement) -> Shape? {
            if let line = element as? DOM.Line {
                let from = Point(line.x1, line.y1)
                let to = Point(line.x2, line.y2)
                return .line(between: [from, to])
            } else if let circle = element as? DOM.Circle {
                let rect = Rect(x: circle.cx - circle.r,
                                y: circle.cy - circle.r,
                                width: circle.r * 2,
                                height: circle.r * 2)
                return .ellipse(within: rect)
            } else if let ellipse = element as? DOM.Ellipse {
                let rect = Rect(x: ellipse.cx - ellipse.rx,
                                y: ellipse.cy - ellipse.ry,
                                width: ellipse.rx * 2,
                                height: ellipse.ry * 2)
                return .ellipse(within: rect)
            } else if let rect = element as? DOM.Rect {
                let radii = Size(rect.rx ?? 0, rect.ry ?? 0)
                let origin = Point(rect.x ?? 0, rect.y ?? 0)
                return .rect(within: Rect(x: origin.x, y: origin.y, width: rect.width, height: rect.height),
                             radii: radii)
            } else if let polyline = element as? DOM.Polyline {
                return .line(between: polyline.points.map{ Point($0.x, $0.y) })
            } else if let polygon = element as? DOM.Polygon {
                return .polygon(between: polygon.points.map{ Point($0.x, $0.y) })
            } else if let domPath = element as? DOM.Path,
                      let path = try? Builder.createPath(from: domPath) {
                return .path(path)
            }
            
            return nil;
        }
    }
}


extension LayerTree.Builder {

    static func createStrokeAttributes(with state: State) -> LayerTree.StrokeAttributes {
        let stroke: LayerTree.Color
        
        if state.strokeWidth > 0.0 {
            stroke = LayerTree.Color.create(from: state.stroke).withAlpha(state.strokeOpacity)
        } else {
            stroke = .none
        }

        return LayerTree.StrokeAttributes(color: stroke,
                                          width: state.strokeWidth,
                                          cap: state.strokeLineCap,
                                          join: state.strokeLineJoin,
                                          miterLimit: state.strokeLineMiterLimit)
    }
    
    static func createFillAttributes(with state: State) -> LayerTree.FillAttributes {
        let fill = LayerTree.Color.create(from: state.fill).withAlpha(state.fillOpacity)
        return LayerTree.FillAttributes(color: fill, rule: state.fillRule)
    }
    
    static func createTextAttributes(with state: State) -> LayerTree.TextAttributes {
        return .normal
    }
    
    //current state of the render tree, updated as builder traverses child nodes
    struct State {
        var opacity: DOM.Float
        var display: DOM.DisplayMode
        
        var stroke: DOM.Color
        var strokeWidth: DOM.Float
        var strokeOpacity: DOM.Float
        var strokeLineCap: DOM.LineCap
        var strokeLineJoin: DOM.LineJoin
        var strokeLineMiterLimit: DOM.Float
        var strokeDashArray: [DOM.Float]
        
        var fill: DOM.Color
        var fillOpacity: DOM.Float
        var fillRule: DOM.FillRule
        
        init() {
            //default root SVG element state
            opacity = 1.0
            display = .inline
            
            stroke = .none
            strokeWidth = 1.0
            strokeOpacity = 1.0
            strokeLineCap = .butt
            strokeLineJoin = .miter
            strokeLineMiterLimit = 4.0
            strokeDashArray = []
            
            fill = .keyword(.black)
            fillOpacity = 1.0
            fillRule = .evenodd
        }
    }
    
    static func createState(for attributes: PresentationAttributes, inheriting existing: State) -> State {
        var state = State()
        
        state.opacity = attributes.opacity ?? existing.opacity
        state.display = attributes.display ?? existing.display
        
        state.stroke = attributes.stroke ?? existing.stroke
        state.strokeWidth = attributes.strokeWidth ?? existing.strokeWidth
        state.strokeOpacity = attributes.strokeOpacity ?? existing.strokeOpacity
        state.strokeLineCap = attributes.strokeLineCap ?? existing.strokeLineCap
        state.strokeLineJoin = attributes.strokeLineJoin ?? existing.strokeLineJoin
        state.strokeDashArray = attributes.strokeDashArray ?? existing.strokeDashArray
        
        state.fill = attributes.fill ?? existing.fill
        state.fillOpacity = attributes.fillOpacity ?? existing.fillOpacity
        state.fillRule = attributes.fillRule ?? existing.fillRule
        
        return state
    }
}

extension LayerTree.Builder {
    static func createTransform(for dom: DOM.Transform) -> LayerTree.Transform {
        switch dom {
        case .matrix(let m):
            return  LayerTree.Transform(a: Float(m.a),
                                        b: Float(m.b),
                                        c: Float(m.c),
                                        d: Float(m.d),
                                        tx: Float(m.e),
                                        ty: Float(m.f))
        case .translate(let t):
            
            return  LayerTree.Transform(tx: Float(t.tx),
                                        ty: Float(t.ty))
        case .scale(let s):
            return  LayerTree.Transform(sx: Float(s.sx),
                                        sy: Float(s.sy))
        case .rotate(let angle):
            let radians = Float(angle)*Float.pi/180.0
            return  LayerTree.Transform(rotate: radians)
            
        case .rotatePoint(let r):
            let radians = Float(r.angle)*Float.pi/180.0
            let point  = LayerTree.Point(r.cx, r.cy)
            return LayerTree.Transform(rotate: radians,
                                       around: point)
            
        case .skewX(let angle):
            let radians = Float(angle)*Float.pi/180.0
            return LayerTree.Transform(skewX: radians)
        case .skewY(let angle):
            let radians = Float(angle)*Float.pi/180.0
            return LayerTree.Transform(skewY: radians)
        }
    }
    
    static func createTransform(concatenating transforms: [DOM.Transform]) -> LayerTree.Transform {
        return transforms.reduce(LayerTree.Transform.identity){ $0.0.concatenated(createTransform(for: $0.1)) }
    }

}
