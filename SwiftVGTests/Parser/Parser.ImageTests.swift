//
//  Parser.ImageTests.swift
//  SwiftVG
//
//  Created by Simon Whitty on 28/1/17.
//  Copyright © 2017 WhileLoop Pty Ltd. All rights reserved.
//

import XCTest
@testable import SwiftVG
import Foundation

class ParserImageTests: XCTestCase {
    
    func loadSVG(_ filename: String) -> DOM.Svg? {
        
        let bundle = Bundle(for: ParserImageTests.self)
        
        guard let url = bundle.url(forResource: filename, withExtension: nil) else {
            return nil
        }
        
        do {
            return try loadSVG(url)
        } catch SwiftVG.XMLParser.Error.invalidElement(let e)  {
            XCTFail("Failed to load \(filename) \(e)")
            return nil
        } catch {
            XCTFail("Failed to load \(filename)")
            return nil
        }
    }
    
    func loadSVG(_ url: URL) throws -> DOM.Svg? {
        let element = try XML.SAXParser.parse(contentsOf: url)
        return try XMLParser().parseSvg(element)
    }
    
    func testShapes() {
        guard let svg = loadSVG("shapes.svg") else {
            XCTFail("failed to load shapes.svg")
            return
        }
        
        XCTAssertEqual(svg.width, 500)
        XCTAssertEqual(svg.height, 700)
        XCTAssertEqual(svg.viewBox?.width, 500)
        XCTAssertEqual(svg.viewBox?.height, 700)
        XCTAssertEqual(svg.defs.clipPaths.count, 2)
        XCTAssertEqual(svg.defs.linearGradients.count, 1)
        XCTAssertNotNil(svg.defs.elements["star"])
        XCTAssertEqual(svg.defs.elements.count, 1)
        
        var c = svg.childElements.enumerated().makeIterator()
        
        XCTAssertTrue(c.next()!.element is DOM.Ellipse)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Circle)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Line)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Path)
        XCTAssertTrue(c.next()!.element is DOM.Polyline)
        XCTAssertTrue(c.next()!.element is DOM.Polyline)
        XCTAssertTrue(c.next()!.element is DOM.Polygon)
        XCTAssertTrue(c.next()!.element is DOM.Group)
        XCTAssertTrue(c.next()!.element is DOM.Circle)
        XCTAssertTrue(c.next()!.element is DOM.Switch)
        XCTAssertTrue(c.next()!.element is DOM.Rect)
        XCTAssertTrue(c.next()!.element is DOM.Text)
        XCTAssertTrue(c.next()!.element is DOM.Line)
        XCTAssertTrue(c.next()!.element is DOM.Use)
        XCTAssertNil(c.next())
    }
    
//    func testStarryPerformance() {
//        self.measure {
//            guard let _ = self.loadSVG("starry.svg") else {
//                    XCTFail("missing group")
//                    return
//            }
//        }
//    }
    
    func testStarry() {
        guard let svg = loadSVG("starry.svg"),
            let g = svg.childElements.first as? DOM.Group,
            let g1 = g.childElements.first as? DOM.Group else {
                XCTFail("missing group")
                return
        }

        XCTAssertEqual(svg.width, 500)
        XCTAssertEqual(svg.height, 500)
        
        XCTAssertEqual(g1.childElements.count, 9323)
        
        var counter = [String: Int]()
        
        for e in g1.childElements {
            let key = String(describing: type(of: e))
            counter[key] = (counter[key] ?? 0) + 1
        }
        
        XCTAssertEqual(counter["Path"], 9314)
        XCTAssertEqual(counter["Polygon"], 9)
    }
    
    func testQuad() {
        guard let svg = loadSVG("quad.svg") else {
            XCTFail("failed to load quad.svg")
            return
        }
        
        XCTAssertEqual(svg.width, 1000)
        XCTAssertEqual(svg.height, 500)
    }
    
    func testCurves() {
        guard let svg = loadSVG("curves.svg") else {
            XCTFail("failed to load curves.svg")
            return
        }
        
        XCTAssertEqual(svg.width, 550)
        XCTAssertEqual(svg.height, 350)
    }
    
    
    func svgFilenames(in folder: String, recursive: Bool = true) -> [URL] {
        var files = [URL]()
        
        let manager = FileManager()
        guard let names = try? manager.contentsOfDirectory(atPath: folder) else { return [] }
        
        for name in names {
            
            let abs = "\(folder)/\(name)"
            
            if name.hasSuffix(".svg") {
                files.append(URL(fileURLWithPath: abs))
            } else if manager.isDirectory(atPath: abs) {
                files.append(contentsOf: svgFilenames(in: abs, recursive: recursive))
            }
        }
        
        return files
    }
    
    func testImages(in folder: String, recursive: Bool = true) {
        for file in svgFilenames(in: folder, recursive: recursive) {
            do {
                _ = try loadSVG(file)
            } catch let e {
                XCTFail("Failed to load SVG \(e)")
            }
        }
    }
    
//    func testImages() {
//       testImages(in: NSString(string: "/Users/swhitty/Projects/Vector").expandingTildeInPath)
//    }
    
}

extension FileManager {
    
    func isDirectory(atPath: String) -> Bool {
        var flag = ObjCBool(false)
        _ = fileExists(atPath: atPath, isDirectory: &flag)
        return flag.boolValue
    }
    
}
