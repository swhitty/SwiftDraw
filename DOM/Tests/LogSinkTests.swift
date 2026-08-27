//
//  LogSinkTests.swift
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
import Testing
@testable import SwiftDrawDOM

struct LogSinkTests {

    @Test
    func levelsAreOrderedBySeverity() {
        #expect(LogSink.Level.info < LogSink.Level.warning)
        #expect(LogSink.Level.warning < LogSink.Level.error)
        #expect(LogSink.Level.allCases == [.info, .warning, .error])
    }

    @Test
    func infoIsWrittenToStandardOutput() {
        let streams = Streams()

        streams.makeHandler()(.info, "Alignment: --insets 1,2,3,4")

        #expect(streams.lines == ["out: Alignment: --insets 1,2,3,4"])
    }

    @Test
    func warningIsPrefixedAndWrittenToStandardError() {
        let streams = Streams()

        streams.makeHandler()(.warning, "PDF does not support transparency masks")

        #expect(streams.lines == ["err: Warning: PDF does not support transparency masks"])
    }

    @Test
    func errorIsWrittenToStandardErrorWithoutPrefix() {
        let streams = Streams()

        streams.makeHandler()(.error, "[parsing error] file.svg <style> error: invalid")

        #expect(streams.lines == ["err: [parsing error] file.svg <style> error: invalid"])
    }

    @Test
    func minimumLevelInfoKeepsEveryMessage() {
        let streams = Streams()
        let handler = streams.makeHandler(minimumLevel: .info)

        for level in LogSink.Level.allCases {
            handler(level, "message")
        }

        #expect(streams.lines == [
            "out: message",
            "err: Warning: message",
            "err: message"
        ])
    }

    @Test
    func minimumLevelWarningDiscardsInfo() {
        let streams = Streams()
        let handler = streams.makeHandler(minimumLevel: .warning)

        for level in LogSink.Level.allCases {
            handler(level, "message")
        }

        #expect(streams.lines == [
            "err: Warning: message",
            "err: message"
        ])
    }

    @Test
    func minimumLevelErrorDiscardsInfoAndWarning() {
        let streams = Streams()
        let handler = streams.makeHandler(minimumLevel: .error)

        for level in LogSink.Level.allCases {
            handler(level, "message")
        }

        #expect(streams.lines == ["err: message"])
    }
}

struct ParsingErrorMessageTests {

    @Test
    func invalidElementWithLocation() {
        let message = XMLParser.makeParsingErrorMessage(
            for: XMLParser.Error.invalidElement(
                name: "rect",
                error: DescribedError(),
                line: 3,
                column: 7
            ),
            filename: "sample.svg"
        )

        #expect(message == "[parsing error] sample.svg <rect> line: 3 column: 7 error: missing width")
    }

    @Test
    func invalidElementWithoutLocation() {
        let message = XMLParser.makeParsingErrorMessage(
            for: XMLParser.Error.invalidElement(
                name: "rect",
                error: XMLParser.Error.invalid,
                line: nil,
                column: nil
            ),
            filename: "sample.svg"
        )

        #expect(message == "[parsing error] sample.svg <rect> error: invalid")
    }

    @Test
    func invalidDocument() {
        let message = XMLParser.makeParsingErrorMessage(
            for: XMLParser.Error.invalidDocument(
                error: nil,
                element: "svg",
                line: 1,
                column: 2
            ),
            filename: "sample.svg"
        )

        #expect(message == "[parsing error] sample.svg <svg> line: 1 column: 2")
    }
}

/// Nested errors are interpolated into the message, so the expected text must not
/// depend on how a given platform reflects an enum with associated values.
private struct DescribedError: Error, CustomStringConvertible {
    var description: String { "missing width" }
}

private final class Streams: @unchecked Sendable {

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func makeHandler(minimumLevel: LogSink.Level = .info) -> LogSink.Handler {
        LogSink.makeHandler(
            minimumLevel: minimumLevel,
            standardOutput: { [self] in append("out: \($0)") },
            standardError: { [self] in append("err: \($0)") }
        )
    }

    @Sendable
    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(line)
    }

    private let lock = NSLock()
    private var stored = [String]()
}
