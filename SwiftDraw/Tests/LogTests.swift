//
//  LogTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 26/8/26.
//  Copyright 2026 Simon Whitty
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
import SwiftDrawDOM
import Testing
@testable import SwiftDraw

struct LogLevelTests {

    @Test
    func levelsAreOrderedBySeverity() {
        #expect(Log.Level.info < Log.Level.warning)
        #expect(Log.Level.warning < Log.Level.error)
        #expect(Log.Level.allCases == [.info, .warning, .error])
    }
}

/// The handler is process wide, so this is the only suite that replaces it.
/// Messages emitted by tests running in parallel are ignored, never asserted on.
@Suite(.serialized)
struct LogTests {

    @Test
    func handlerReceivesEveryLevel() {
        let messages = Messages()
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = { messages.append($0, $1) }
        let handler = Log.handler

        handler(.info, "\(token) alignment")
        handler(.warning, "\(token) unsupported")
        handler(.error, "\(token) invalid")

        #expect(messages.lines == [
            "info: \(token) alignment",
            "warning: \(token) unsupported",
            "error: \(token) invalid"
        ])
    }

    @Test
    func handlerCanBeRestored() {
        let messages = Messages()
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = { messages.append($0, $1) }
        let restored = Log.handler

        Log.handler = Log.silent
        Log.handler = restored

        Log.handler(.warning, "\(token) unsupported")

        #expect(messages.lines == ["warning: \(token) unsupported"])
    }

    @Test
    func silentDiscardsMessages() {
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = Log.silent

        Log.handler(.info, "\(token) alignment")
        Log.handler(.warning, "\(token) unsupported")
        Log.handler(.error, "\(token) invalid")
    }

    @Test
    func emittedMessagesReachTheHandler() {
        let messages = Messages()
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = { messages.append($0, $1) }

        LogSink.info("\(token) alignment")
        LogSink.warning("\(token) unsupported")
        LogSink.error("\(token) invalid")

        #expect(messages.lines == [
            "info: \(token) alignment",
            "warning: \(token) unsupported",
            "error: \(token) invalid"
        ])
    }

    // Commands are only generated when CoreGraphics is available; the renderer
    // emits no warnings on other platforms.
#if canImport(CoreGraphics)
    @Test
    func renderingWarningsReachTheHandler() throws {
        let messages = Messages(filter: nil)
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = { messages.append($0, $1) }

        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="fade">
                    <stop offset="0" stop-color="black" stop-opacity="0"/>
                    <stop offset="1" stop-color="black" stop-opacity="1"/>
                </linearGradient>
            </defs>
            <rect width="100" height="100" fill="url(#fade)"/>
        </svg>
        """#

        let dom = try DOM.SVG.parse(data: Data(xml.utf8))
        _ = SVG(dom: dom, options: [.disableTransparencyLayers])

        #expect(messages.lines.contains("warning: PDF does not support gradients with stop-opacity"))
    }
#endif

    @Test
    func parsingErrorsReachTheHandler() throws {
        let messages = Messages(filter: nil)
        let original = Log.handler
        defer { Log.handler = original }

        Log.handler = { messages.append($0, $1) }

        XMLParser.logParsingError(for: XMLParser.Error.invalid, filename: "empire.svg")

        #expect(messages.lines.contains("error: [parsing error] empire.svg  error: invalid"))
    }
}

private let token = "LogTests"

private final class Messages: @unchecked Sendable {

    init(filter: String? = token) {
        self.filter = filter
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    @Sendable
    func append(_ level: Log.Level, _ message: String) {
        guard filter.map(message.contains) ?? true else { return }
        lock.lock()
        defer { lock.unlock() }
        stored.append("\(level): \(message)")
    }

    private let filter: String?
    private let lock = NSLock()
    private var stored = [String]()
}
