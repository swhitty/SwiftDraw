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
    
    //Tracks the state of the renderer to enable rudant calls to be omitted
    //The RenderState is inherited by Elements to provide non-nil values for these attributes
    //DOMState attributes always override the inherited RenderState
    struct RendererState: Equatable {
        var fillColor: Color
        var strokeColor: Color
        var strokeWidth: Float
        
        static func ==(lhs: RendererState, rhs: RendererState) -> Bool {
            return lhs.fillColor == rhs.fillColor &&
                   lhs.strokeColor == rhs.strokeColor &&
                   lhs.strokeWidth == rhs.strokeWidth
        }
        
        static var defaultSvg: RendererState {
            return RendererState(fillColor: Color(DOM.Color.keyword(.black)),
                                 strokeColor: .none,
                                 strokeWidth: 1.0)
        }
    }
    
    func createAttributes(for attributes: PresentationAttributes, inheriting existing: PresentationAttributes) -> PresentationAttributes {
        
        var state = DOMState()
        
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
        
        //i don't think these should be inherited.
        state.transform = attributes.transform
        state.clipPath = attributes.clipPath
        state.mask = attributes.mask
        
        return state
        
    }
    
    func createState(for attributes: PresentationAttributes, with existing: RendererState) -> RendererState {
        var state = existing
        
        state.fillColor = attributes.fill.map{ Color($0) } ?? state.fillColor
        if let fillOpacity = attributes.fillOpacity {
            state.fillColor = state.fillColor.withAlpha(fillOpacity)
        }
        
        state.strokeColor = attributes.stroke.map{ Color($0) } ?? state.strokeColor
        if let strokeOpacity = attributes.strokeOpacity {
            state.strokeColor = state.strokeColor.withAlpha(strokeOpacity)
        }
        
        state.strokeWidth = attributes.strokeWidth ?? state.strokeWidth

        return state
    }

    func createCommands<T: RendererTypeProvider>(for state: RendererState, existing: RendererState? = nil, with provider: T) -> [RendererCommand<T>] {
        var commands = [RendererCommand<T>]()
        
        if state.fillColor != existing?.fillColor,
           state.fillColor != .none {
            let fill = provider.createColor(from: state.fillColor)
            commands.append(.setFill(color: fill))
        }
        
        if state.strokeColor != existing?.strokeColor,
           state.strokeColor != .none {
            let stroke = provider.createColor(from: state.strokeColor)
            commands.append(.setStroke(color: stroke))
        }
        
        if state.strokeWidth != existing?.strokeWidth {
            let stroke = provider.createFloat(from: state.strokeWidth)
            commands.append(.setLine(width: stroke))
        }
        
        return commands
    }
}
