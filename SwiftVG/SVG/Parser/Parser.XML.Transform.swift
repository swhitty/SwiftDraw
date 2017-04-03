//
//  Parser.XML.Transform.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

extension XMLParser {
    
    func parseTransform(_ data: String) throws -> [DOM.Transform] {
        
        var scanner = Scanner(text: data)
        var transforms = Array<DOM.Transform>()
        
        while let transform = try parseTransform(&scanner) {
            transforms.append(transform)
        }
        
        guard scanner.isEOF else {
            // expecting EOF
            throw Error.invalid
        }
        
        return transforms
    }
    
    func parseTransform(_ scanner: inout Scanner) throws -> DOM.Transform? {
        
        if let t = try parseMatrix(&scanner) {
            return t
        } else if let t = try parseTranslate(&scanner) {
            return t
        } else if let t = try parseScale(&scanner) {
            return t
        } else if let t = try parseRotate(&scanner) {
            return t
        } else if let t = try parseSkewX(&scanner) {
            return t
        } else if let t = try parseSkewY(&scanner) {
            return t
        }
        return nil
    }
    
    func parseMatrix(_ scanner: inout Scanner) throws -> DOM.Transform? {
        
        guard scanner.scan("matrix(") != nil else {
            return nil
        }
        
        let a = try scanner.scanFloat()
        _ = scanner.scan(",")
        let b = try scanner.scanFloat()
        _ = scanner.scan(",")
        let c = try scanner.scanFloat()
        _ = scanner.scan(",")
        let d = try scanner.scanFloat()
        _ = scanner.scan(",")
        let e = try scanner.scanFloat()
        _ = scanner.scan(",")
        let f = try scanner.scanFloat()
        
        guard scanner.scan(")") != nil else {
            throw Error.invalid
        }
        
        return .matrix(a: a, b: b, c: c, d: d, e: e, f: f)
    }
    
    func parseTranslate(_ scanner: inout Scanner) throws -> DOM.Transform? {
        guard scanner.scan("translate(") != nil else {
            return nil
        }
        
        let tx = try scanner.scanFloat()
        if let _ = scanner.scan(")") {
            return .translate(tx: tx, ty: 0)
        }
        
        _ = scanner.scan(",")
        let ty = try scanner.scanFloat()
        
        guard scanner.scan(")") != nil else {
            throw Error.invalid
        }
        
        return .translate(tx: tx, ty: ty)
    }
    
    func parseScale(_ scanner: inout Scanner) throws -> DOM.Transform? {
        guard scanner.scan("scale(") != nil else {
            return nil
        }
        
        let sx = try scanner.scanFloat()
        if let _ = scanner.scan(")") {
            return .scale(sx: sx, sy: sx)
        }
        
        _ = scanner.scan(",")
        let sy = try scanner.scanFloat()
        
        guard scanner.scan(")") != nil else {
            throw Error.invalid
        }
        
        return .scale(sx: sx, sy: sy)
    }
    
    func parseRotate(_ scanner: inout Scanner) throws -> DOM.Transform? {
        guard scanner.scan("rotate(") != nil else {
            return nil
        }
        
        let angle = try scanner.scanFloat()
        if let _ = scanner.scan(")") {
            return .rotate(angle: angle)
        }
        
        _ = scanner.scan(",")
        let cx = try scanner.scanFloat()
        _ = scanner.scan(",")
        let cy = try scanner.scanFloat()
        
        guard scanner.scan(")") != nil else {
            throw Error.invalid
        }
        
        return .rotatePoint(angle: angle, cx: cx, cy: cy)
    }
    
    func parseSkewX(_ scanner: inout Scanner) throws -> DOM.Transform? {
        guard scanner.scan("skewX(") != nil else {
            return nil
        }
        
        let angle = try scanner.scanFloat()
        
        guard scanner.scan(")") != nil else {
            throw Error.invalid
        }
        return .skewX(angle: angle)
    }
    
    func parseSkewY(_ scanner: inout Scanner) throws -> DOM.Transform? {
        guard scanner.scan("skewY(") != nil else {
            return nil
        }
        
        let angle = try scanner.scanFloat()
        
        guard scanner.scan(")") != nil else {
            throw Error.invalid
        }
        return .skewY(angle: angle)
    }
}
