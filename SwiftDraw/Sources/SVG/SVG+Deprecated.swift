//
//  SVG+Deprecated.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 23/2/25.
//  Copyright 2025 Simon Whitty
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

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

public extension SVG {

    @available(*, deprecated, message: "add insets via SVG.expand() before pngData")
    func pngData(scale: CGFloat = 0, insets: Insets) throws -> Data {
        try inset(insets).pngData(scale: scale)
    }

    @available(*, deprecated, message: "set size via SVG.size() before pngData")
    func pngData(size: CGSize, scale: CGFloat = 0) throws -> Data {
        try self.sized(size).pngData(scale: scale)
    }

    @available(*, deprecated, message: "add insets via SVG.expand() before jpegData")
    func jpegData(scale: CGFloat = 0, compressionQuality quality: CGFloat = 1, insets: Insets) throws -> Data {
        try inset(insets).jpegData(scale: scale, compressionQuality: quality)
    }

    @available(*, deprecated, message: "set size via SVG.size() before jpegData")
    func jpegData(size: CGSize, scale: CGFloat = 0, compressionQuality quality: CGFloat = 1) throws -> Data {
        try self.sized(size).jpegData(scale: scale, compressionQuality: quality)
    }

    private func inset(_ insets: Insets) -> SVG {
        expanded(top: -insets.top, left: -insets.left, bottom: -insets.bottom, right: -insets.right)
    }

#if canImport(UIKit)
    @available(*, deprecated, message: "add insets via SVG.expand() before rasterize()")
    func rasterize(scale: CGFloat = 0, insets: UIEdgeInsets) -> UIImage {
        inset(insets).rasterize(scale: scale)
    }

    @available(*, deprecated, message: "add insets via SVG.expand() before pngData()")
    func pngData(scale: CGFloat = 0, insets: UIEdgeInsets) throws -> Data {
        try inset(insets).pngData(scale: scale)
    }

    @available(*, deprecated, message: "add insets via SVG.expand() before jpegData()")
    func jpegData(scale: CGFloat = 0, compressionQuality quality: CGFloat = 1, insets: UIEdgeInsets) throws -> Data {
        try inset(insets).jpegData(scale: scale, compressionQuality: quality)
    }

    private func inset(_ insets: UIEdgeInsets) -> SVG {
        expanded(top: -insets.top, left: -insets.left, bottom: -insets.bottom, right: -insets.right)
    }
#endif

}
#endif
