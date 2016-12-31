//
//  DOM.Equality.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

@testable import SwiftVG

//Equatable just for tests

extension DOM.GraphicsElement: Equatable {
    public static func ==(lhs: DOM.GraphicsElement, rhs: DOM.GraphicsElement) -> Bool {
        let toString : (Any) -> String = { var text = ""; dump($0, to: &text); return text }
        return toString(lhs) == toString(rhs)
    }
}
