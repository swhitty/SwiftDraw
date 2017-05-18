//
//  Builder.State.swift
//  SwiftVG
//
//  Created by Simon Whitty on 27/3/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
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
        var opacity: DOM.Float = 1.0
        var display: DOM.DisplayMode = .inline
        
        var stroke: DOM.Color = .none
        var strokeWidth: DOM.Float = 1.0
        var strokeOpacity: DOM.Float = 1.0
        var strokeLineCap: DOM.LineCap = .butt
        var strokeLineJoin: DOM.LineJoin = .bevel
        var strokeDashArray: [DOM.Float] = []
        
        var fill: DOM.Color = .keyword(.black)
        var fillOpacity: DOM.Float = 1.0
        var fillRule: DOM.FillRule = .nonzero
        
        init() {
            opacity = 1.0
            display = .inline
            
            stroke = .none
            strokeWidth = 1.0
            strokeOpacity = 1.0
            strokeLineCap = .butt
            strokeLineJoin = .bevel
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
