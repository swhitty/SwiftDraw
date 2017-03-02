//
//  XML.swift
//  SwiftVG
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright © 2016 WhileLoop Pty Ltd. All rights reserved.
//

struct XML {
    class Element {
        
        var name: String
        var attributes: [String: String]
        var children = [Element]()
        var innerText: String?
        
        var parsedLocation: (line: Int, column: Int)?
        
        init(name: String, attributes: [String: String] = [:]) {
            self.name = name
            self.attributes = attributes
            self.innerText = nil
        }
    }
}
