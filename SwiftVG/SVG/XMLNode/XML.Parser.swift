//
//  XML.Parser.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/1/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import Foundation

extension XML {
    
    class SAXParser: NSObject, XMLParserDelegate {
        
        typealias XMLParser = Foundation.XMLParser
        
        let parser: XMLParser
        let namespaceURI = "http://www.w3.org/2000/svg"
        
        var rootNode: Element?
        var elements: [Element]
        
        init?(contentsOf url: URL) {
            guard let parser = XMLParser(contentsOf: url) else {
                return nil
            }
            self.parser = parser
            elements = [Element]()
            super.init()
            
            parser.delegate = self
            parser.shouldProcessNamespaces = true
        }
        
        static func parse(contentsOf url: URL) throws -> Element {
            guard let parser = SAXParser(contentsOf: url) else {
                throw SwiftVG.XMLParser.Error.invalid
            }
            
            parser.parser.parse()
            
            guard let rootNode = parser.rootNode else {
                throw SwiftVG.XMLParser.Error.invalid
            }
            
            return rootNode
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
            guard self.parser === parser,
                namespaceURI == self.namespaceURI else { return }
            
            let element = Element(name: elementName, attributes: attributeDict)
            
            elements.last?.children.append(element)
            elements.append(element)
            
            if rootNode == nil {
                rootNode = element
            }
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName _: String?) {
            guard self.parser === parser,
                namespaceURI == self.namespaceURI,
                let element = self.elements.last,
                element.name == elementName else { return }
            
            elements.removeLast()
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard self.parser === parser,
                let element = elements.last else { return }
            
            let innerText = element.innerText ?? ""
            element.innerText = innerText + string
        }
        
        //        func parse() -> XMLElement? {
        //
        //            self.rootNode = nil
        //            self.elements = [XMLElement]()
        //            parser.parse()
        //
        //            return self.rootNode
        //        }
        
    }
    
}
