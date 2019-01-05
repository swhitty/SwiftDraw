//
//  CGRendererTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/12/18.
//  Copyright 2018 Simon Whitty
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

@testable import SwiftDraw
import CoreGraphics
import AppKit
import XCTest

final class CGRendererTests: XCTestCase {

    func testDrawsRect() {
        let renderer = ImageRenderer(pixelsWide: 2, pixelsHigh: 2)

        renderer.renderer.setFill(color: .red)
        renderer.renderer.fill(path: CGPath.rect(), rule: .evenOdd)

        XCTAssertEqual(renderer.getColor(x: 0, y: 0), .red)
        XCTAssertEqual(renderer.getColor(x: 1, y: 1), .red)
    }

    func testAlphaClips() {
        let renderer = ImageRenderer(pixelsWide: 2, pixelsHigh: 2)

        renderer.renderer.setFill(color: .red)
        renderer.renderer.fill(path: CGPath.rect(), rule: .evenOdd)

        XCTAssertEqual(renderer.getColor(x: 0, y: 0), .red)
        XCTAssertEqual(renderer.getColor(x: 1, y: 1), .red)
    }
}

final class ImageRenderer {

    let renderer: CGRenderer
    private let bitmap: NSBitmapImageRep

    init(pixelsWide: Int, pixelsHigh: Int) {
        self.bitmap = NSBitmapImageRep(pixelsWide: pixelsWide,
                                       pixelsHigh: pixelsHigh)
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
        self.renderer = CGRenderer(context: context)
    }

    func getColor(x: Int, y: Int) -> CGColor? {
        return bitmap.colorAt(x: x, y: y)?.cgColor
    }
}

private extension CGPath {

    static func rect(x: CGFloat = 0,
                     y: CGFloat = 0,
                     width: CGFloat = 2,
                     height: CGFloat = 2) -> CGPath {

        let rect = CGRect(x: x, y: y, width: width, height: height)
        return CGPath(rect: rect, transform: nil)
    }
}

private extension CGColor {

    static var red: CGColor {
        //return CGColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)
        return NSColor(deviceRed: 0.0, green: 0, blue: 1.0, alpha: 1.0).cgColor
    }
}
