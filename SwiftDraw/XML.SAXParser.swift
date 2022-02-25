//
//  XML.SAXParser.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 28/1/17.
//  Copyright 2020 Simon Whitty
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
#if canImport(FoundationXML)
import FoundationXML
#endif

extension XML {
  
  final class SAXParser: NSObject, XMLParserDelegate {
    
    #if canImport(FoundationXML)
    typealias XMLParser = FoundationXML.XMLParser
    #else
    typealias XMLParser = Foundation.XMLParser
    #endif
    
    private let parser: XMLParser
    private let namespaceURI = "http://www.w3.org/2000/svg"
    
    private var rootNode: Element?
    private var elements: [Element]
    
    private var currentElement: Element {
      return elements.last!
    }
    
    private init(data: Data) {
      self.parser = XMLParser(data: data)
      elements = [Element]()
      super.init()
      
      self.parser.delegate = self
      self.parser.shouldProcessNamespaces = true
    }
    
    static func parse(data: Data) throws -> Element {
      let parser = SAXParser(data: data)
      
      guard
        parser.parser.parse(),
        let rootNode = parser.rootNode else {
          let error = parser.parser.parserError ?? SwiftDraw.XMLParser.Error.invalid
          throw error
      }
      
      return rootNode
    }
    
    static func parse(contentsOf url: URL) throws -> Element {
      let data = try Data(contentsOf: url)
      return try parse(data: data)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
      guard
        self.parser === parser,
        namespaceURI == self.namespaceURI else {
          return
      }
      
      let element = Element(name: elementName, attributes: attributeDict)
      element.parsedLocation = (line: parser.lineNumber, column: parser.columnNumber)
      
      elements.last?.children.append(element)
      elements.append(element)
      
      if rootNode == nil {
        rootNode = element
      }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName _: String?) {
      guard
        namespaceURI == self.namespaceURI,
        currentElement.name == elementName else {
          return
      }
      
      elements.removeLast()
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
      guard let element = elements.last else { return }
      let text = element.innerText.map { $0.appending(string) }
      element.innerText = text ?? string
    }
  }
}
