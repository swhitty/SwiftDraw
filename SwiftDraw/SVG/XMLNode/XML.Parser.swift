//
//  XML.Parser.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/1/17.
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
                throw SwiftDraw.XMLParser.Error.invalid
            }
            
            parser.parser.parse()
            
            guard let rootNode = parser.rootNode else {
                throw SwiftDraw.XMLParser.Error.invalid
            }
            
            return rootNode
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
            guard self.parser === parser,
                namespaceURI == self.namespaceURI else { return }
            
            let element = Element(name: elementName, attributes: attributeDict)
            element.parsedLocation = (line: parser.lineNumber, column: parser.columnNumber)
            
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
