//
//  Builder.State.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 27/3/17.
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

extension Builder {
    
    //Tracks the state of the current DOM.GraphicsElement
    //Elements inherit attributes from their parent
    struct DOMState: PresentationAttributes {
        var opacity: DOM.Float?
        var display: DOM.DisplayMode?
        
        var stroke: DOM.Color?
        var strokeWidth: DOM.Float?
        var strokeOpacity: DOM.Float?
        var strokeLineCap: DOM.LineCap?
        var strokeLineJoin: DOM.LineJoin?
        var strokeDashArray: [DOM.Float]?
        
        var fill: DOM.Color?
        var fillOpacity: DOM.Float?
        var fillRule: DOM.FillRule?
        
        var transform: [DOM.Transform]?
        var clipPath: DOM.URL?
        var mask: DOM.URL?
        
        static var defaultSvg: DOMState {
            var state = DOMState()
            state.fill = DOM.Color.keyword(.black)
            state.stroke = DOM.Color.none
            state.strokeWidth = 1.0
            return state
        }
    }
    
    //current state of the render tree
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
    
    func createState(for attributes: PresentationAttributes, inheriting existing: State) -> State {
        
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
