//
//  AsyncSVGViewTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 18/7/26.
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

#if canImport(SwiftUI)
import Foundation
@testable import SwiftDraw
import Testing

struct AsyncSVGViewTests {

    @Test
    func phaseExposesSVGAndError() throws {
        let svg = try #require(SVG(xml: Self.validSVG))

        #expect(AsyncSVGPhase.empty.svg == nil)
        #expect(AsyncSVGPhase.empty.error == nil)

        let success = AsyncSVGPhase.success(svg)
        #expect(success.svg == svg)
        #expect(success.error == nil)

        let failure = AsyncSVGPhase.failure(URLError(.timedOut))
        #expect(failure.svg == nil)
        #expect((failure.error as? URLError)?.code == .timedOut)
    }

    @Test
    func loaderUsesURLRequestAndURLSession() async throws {
        var request = URLRequest(url: URL(string: "https://example.invalid/image.svg")!)
        request.setValue("SwiftDraw", forHTTPHeaderField: "X-Loader")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SVGTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let loaded = try await AsyncSVGLoader.load(
            from: request,
            options: .hideUnsupportedFilters,
            session: session
        )

        #expect(loaded.size.width == 20)
        #expect(loaded.size.height == 10)
    }

    @Test
    func loaderRejectsHTTPFailure() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://example.com/image.svg")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        ))

        do {
            try AsyncSVGLoader.validate(response)
            Issue.record("Expected an unsuccessful HTTP response to throw")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        }
    }

    @Test
    func loaderAcceptsSuccessfulHTTPResponse() throws {
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://example.com/image.svg")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))

        #expect(throws: Never.self) {
            try AsyncSVGLoader.validate(response)
        }
    }

    private static let validSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="10">
      <rect width="20" height="10" fill="red" />
    </svg>
    """
}

private final class SVGTestURLProtocol: URLProtocol, @unchecked Sendable {

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "example.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let statusCode = request.value(forHTTPHeaderField: "X-Loader") == "SwiftDraw" ? 200 : 400
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/svg+xml"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.svgData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }

    private static let svgData = Data("""
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="10">
      <rect width="20" height="10" fill="red" />
    </svg>
    """.utf8)
}
#endif
