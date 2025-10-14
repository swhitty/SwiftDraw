//
//  CommandLine.Configuration.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 7/12/18.
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

import SwiftDrawDOM
public import Foundation

extension CommandLine {

    public struct Configuration {
        public var input: URL
        public var inputUltralight: URL?
        public var inputBlack: URL?
        public var output: URL
        public var format: Format
        public var size: Size
        public var api: API?
        public var insets: Insets
        public var insetsUltralight: Insets?
        public var insetsBlack: Insets?
        public var scale: Scale
        public var options: SVG.Options
        public var precision: Int?
        public var symbolSize: SFSymbolRenderer.SizeCategory?
        public var isLegacyInsetsEnabled: Bool
    }

    public enum Format: String {
        case jpeg
        case pdf
        case png
        case swift
        case sfsymbol
    }

    public enum API: String {
        case appkit
        case uikit
    }

    public enum Size: Equatable {
        case `default`
        case custom(width: Int, height: Int)
    }

    public enum Scale: Equatable {
        case `default`
        case retina
        case superRetina
    }

    public struct Insets: Equatable {
        public var top: Double?
        public var left: Double?
        public var bottom: Double?
        public var right: Double?

        public init(top: Double? = nil, left: Double? = nil, bottom: Double? = nil, right: Double? = nil) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }

        var isEmpty: Bool {
            top == nil && left == nil && bottom == nil && right == nil
        }
    }

    public static func parseConfiguration(from args: [String], baseDirectory: URL) throws -> Configuration {
        guard args.count > 2 else {
            throw Error.invalid
        }

        let source = try parseFileURL(file: args[1], within: baseDirectory)
        let modifiers = try parseModifiers(from: Array(args.dropFirst(2)))
        guard
            let formatString = modifiers[.format],
            let formatString = formatString,
            let format = Format(rawValue: formatString) else {
            throw Error.invalid
        }

        let size = try parseSize(from: modifiers[.size], format: format)
        let scale = try parseScale(from: modifiers[.scale])
        let precision = try parsePrecision(from: modifiers[.precision])
        let insets = try parseInsets(from: modifiers[.insets]) ?? Insets()
        let api = try parseAPI(from: modifiers[.api])
        let ultralight = try parseFileURL(file: modifiers[.ultralight], within: baseDirectory)
        let ultralightInsets = try parseInsets(from: modifiers[.ultralightInsets])
        let black = try parseFileURL(file: modifiers[.black], within: baseDirectory)
        let blackInsets = try parseInsets(from: modifiers[.blackInsets])
        let output = try parseFileURL(file: modifiers[.output], within: baseDirectory)
        let symbolSize = try parseSymbolSize(from: modifiers[.size], format: format)

        let options = try parseOptions(from: modifiers)
        let result = source.newURL(for: format, scale: scale)
        return Configuration(
            input: source,
            inputUltralight: ultralight,
            inputBlack: black,
            output: output ?? result,
            format: format,
            size: size,
            api: api,
            insets: insets,
            insetsUltralight: ultralightInsets,
            insetsBlack: blackInsets,
            scale: scale,
            options: options,
            precision: precision,
            symbolSize: symbolSize,
            isLegacyInsetsEnabled: modifiers.keys.contains(.legacy)
        )
    }

    static func parseFileURL(file: String, within directory: URL) throws -> URL {
        guard #available(macOS 10.11, *) else {
            throw Error.invalid
        }

        return URL(fileURLWithPath: file, relativeTo: directory).standardizedFileURL
    }

    static func parseFileURL(file: String??, within directory: URL) throws -> URL? {
        guard let file = file,
              let file = file else {
            return nil
        }
        return try parseFileURL(file: file, within: directory)
    }

    static func parseScale(from value: String??) throws -> Scale {
        guard let value = value,
              let value = value else {
            return .default
        }

        guard let scale = Scale(value) else {
            throw Error.invalid
        }
        return scale
    }

    static func parsePrecision(from value: String??) throws -> Int? {
        guard let value = value,
              let value = value else {
            return nil
        }

        guard let precision = Int(value) else {
            throw Error.invalid
        }
        return precision
    }

    static func parseSize(from value: String??, format: Format) throws -> Size {
        guard format != .sfsymbol,
              let value = value,
              let value = value else {
            return .default
        }

        let scanner = Scanner(string: value)
        guard
            let width = scanner.scanInt32(),
            let _ = scanner.scanString("x"),
            let height = scanner.scanInt32(),
            width > 0, height > 0 else {
            throw Error.invalid
        }

        return .custom(width: Int(width), height: Int(height))
    }

    static func parseSymbolSize(from value: String??, format: Format) throws -> SFSymbolRenderer.SizeCategory? {
        guard format == .sfsymbol,
              let value = value,
              let value = value else {
            return nil
        }

        switch value {
        case "small":
            return .small
        case "medium":
            return .medium
        case "large":
            return .large
        default:
            throw Error.invalid

        }
    }

    static func parseAPI(from value: String??) throws -> API? {
        guard let value = value,
              let value = value else {
            return nil
        }

        guard let api = API(rawValue: value) else {
            throw Error.invalid
        }
        return api
    }

    static func parseInsets(from value: String??) throws -> Insets? {
        guard let value = value,
              let value = value else {
            return nil
        }

        guard value != "auto" else {
            return Insets()
        }

        var scanner = XMLParser.Scanner(text: value)
        let top = try scanner.scanInset()
        _ = try scanner.scanString(",")
        let left = try scanner.scanInset()
        _ = try scanner.scanString(",")
        let bottom = try scanner.scanInset()
        _ = try scanner.scanString(",")
        let right = try  scanner.scanInset()
        return Insets(
            top: top,
            left: left,
            bottom: bottom,
            right: right
        )
    }

    static func parseOptions(from modifiers: [CommandLine.Modifier: String?]) throws -> SVG.Options {
        var options: SVG.Options = .default

        if modifiers.keys.contains(.hideUnsupportedFilters) {
            options.insert(.hideUnsupportedFilters)
        }

        return options
    }
}

private extension DOMXMLParser.Scanner {

    mutating func scanInset() throws -> Double? {
        guard !scanStringIfPossible("auto") else {
            return nil
        }
        return try scanDouble()
    }
}

extension SVG.Options {
    static var disableTransparencyLayers: SVG.Options { Self(rawValue: 1 << 8) }
    static var commandLine: SVG.Options { Self(rawValue: 1 << 9) }
}

extension URL {

    var lastPathComponentName: String {
        let filename = lastPathComponent
        let extensionOffset = pathExtension.isEmpty ? 0 : -pathExtension.count - 1
        let index = filename.index(filename.endIndex, offsetBy: extensionOffset)
        return String(filename[..<index])
    }

    func newURL(for format: CommandLine.Format, scale: CommandLine.Scale) -> URL {
        let suffix = Self.lastPathComponentSuffix(format: format, scale: scale)
        let newfilename = "\(lastPathComponentName)\(suffix).\(format.pathExtension)"
        return deletingLastPathComponent()
            .appendingPathComponent(newfilename)
            .standardizedFileURL
    }

    static func lastPathComponentSuffix(format: CommandLine.Format, scale: CommandLine.Scale) -> String {
        switch (format, scale) {
        case (.sfsymbol, _):
            return "-symbol"
        case (.png, .retina):
            return "@2x"
        case (.png, .superRetina):
            return "@3x"
        default:
            return ""
        }
    }
}

private extension CommandLine.Format {

    var pathExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .pdf:
            return "pdf"
        case .png:
            return "png"
        case .swift:
            return "swift"
        case .sfsymbol:
            return "svg"
        }
    }
}

private extension CommandLine.Scale {

    init?(_ value: String) {
        switch value {
        case "1x":
            self = .default
        case "2x":
            self = .retina
        case "3x":
            self = .superRetina
        default:
            return nil
        }
    }
}
