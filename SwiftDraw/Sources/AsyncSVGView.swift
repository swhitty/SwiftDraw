//
//  AsyncSVGView.swift
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
public import SwiftUI
import Foundation

private extension EnvironmentValues {
    @Entry var asyncSVGURLSession: URLSession = .shared
}

public extension View {
    /// Sets the URL session used by `AsyncSVGView` instances in this view hierarchy.
    func asyncSVGURLSession(_ session: URLSession) -> some View {
        environment(\.asyncSVGURLSession, session)
    }
}

/// The current result of loading an SVG asynchronously.
public enum AsyncSVGPhase: Sendable {
    /// No SVG has been loaded yet.
    case empty

    /// An SVG was loaded successfully.
    case success(SVG)

    /// Loading or parsing the SVG failed.
    case failure(any Error)

    /// The successfully loaded SVG, if one is available.
    public var svg: SVG? {
        guard case let .success(svg) = self else { return nil }
        return svg
    }

    /// The loading or parsing error, if one occurred.
    public var error: (any Error)? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

/// A view that asynchronously loads and displays a remote SVG.
public struct AsyncSVGView<Content>: View where Content: View {

    private let request: URLRequest?
    private let options: SVG.Options
    private let transaction: Transaction
    private let content: (AsyncSVGPhase, SVGViewConfiguration) -> Content
    private var svgViewConfiguration = SVGViewConfiguration()

    @Environment(\.asyncSVGURLSession) private var session
    @State private var phase: AsyncSVGPhase = .empty
    @State private var phaseRequestID: RequestID?

    /// Loads and displays an SVG from a URL.
    public init(
        url: URL?,
        options: SVG.Options = .default
    ) where Content == SVGView? {
        self.init(request: url.map { URLRequest(url: $0) }, options: options)
    }

    /// Loads and displays an SVG using a URL request.
    public init(
        request: URLRequest?,
        options: SVG.Options = .default
    ) where Content == SVGView? {
        self.request = request
        self.options = options
        self.transaction = Transaction()
        self.content = { phase, configuration in
            phase.svg.map {
                configuration.apply(to: SVGView(svg: $0))
            }
        }
    }

    /// Sets the resizing behavior of the `SVGView` created by the default
    /// initializer.
    public func resizable(
        capInsets: EdgeInsets = EdgeInsets(),
        resizingMode: SVGView.ResizingMode = .stretch
    ) -> Self where Content == SVGView? {
        var copy = self
        copy.svgViewConfiguration.resizable = (capInsets, resizingMode)
        return copy
    }

    /// Loads an SVG and supplies it or a placeholder to the respective closure.
    public init<I, P>(
        url: URL?,
        options: SVG.Options = .default,
        @ViewBuilder content: @escaping (SVG) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P>, I: View, P: View {
        self.init(
            request: url.map { URLRequest(url: $0) },
            options: options,
            content: content,
            placeholder: placeholder
        )
    }

    /// Loads an SVG using a URL request and supplies it or a placeholder to the
    /// respective closure.
    public init<I, P>(
        request: URLRequest?,
        options: SVG.Options = .default,
        @ViewBuilder content: @escaping (SVG) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P>, I: View, P: View {
        self.init(request: request, options: options) { phase in
            if let svg = phase.svg {
                content(svg)
            } else {
                placeholder()
            }
        }
    }

    /// Loads an SVG and supplies the current loading phase to a custom view builder.
    public init(
        url: URL?,
        options: SVG.Options = .default,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncSVGPhase) -> Content
    ) {
        self.init(
            request: url.map { URLRequest(url: $0) },
            options: options,
            transaction: transaction,
            content: content
        )
    }

    /// Loads an SVG using a URL request and supplies the current loading phase
    /// to a custom view builder.
    public init(
        request: URLRequest?,
        options: SVG.Options = .default,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncSVGPhase) -> Content
    ) {
        self.request = request
        self.options = options
        self.transaction = transaction
        self.content = { phase, _ in content(phase) }
    }

    public var body: some View {
        ZStack {
            content(phase, svgViewConfiguration)
        }
        .compatibilityTask(id: requestID) {
            await loadIfNeeded(for: requestID, session: session)
        }
    }

    private var requestID: RequestID {
        RequestID(
            request: request,
            options: options.rawValue,
            session: ObjectIdentifier(session)
        )
    }

    @MainActor
    private func loadIfNeeded(for requestID: RequestID, session: URLSession) async {
        guard phaseRequestID != requestID || phase.svg == nil else { return }
        phaseRequestID = requestID

        guard let request = requestID.request else {
            setPhase(.empty)
            return
        }

        let options = SVG.Options(rawValue: requestID.options)
        setPhase(.empty)

        do {
            let svg = try await AsyncSVGLoader.load(
                from: request,
                options: options,
                session: session
            )
            try Task.checkCancellation()
            guard phaseRequestID == requestID else { return }
            setPhase(.success(svg))
        } catch {
            guard !Task.isCancelled, phaseRequestID == requestID else { return }
            setPhase(.failure(error))
        }
    }

    @MainActor
    private func setPhase(_ phase: AsyncSVGPhase) {
        withTransaction(transaction) {
            self.phase = phase
        }
    }

    private struct RequestID: Hashable {
        var request: URLRequest?
        var options: Int
        var session: ObjectIdentifier
    }

    private struct SVGViewConfiguration {
        var resizable: (capInsets: EdgeInsets, mode: SVGView.ResizingMode)?

        @MainActor
        func apply(to view: SVGView) -> SVGView {
            guard let resizable else { return view }
            return view.resizable(
                capInsets: resizable.capInsets,
                resizingMode: resizable.mode
            )
        }
    }
}

enum AsyncSVGLoader {

    static func load(
        from request: URLRequest,
        options: SVG.Options,
        session: URLSession = .shared
    ) async throws -> SVG {
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        try validate(response)
        try Task.checkCancellation()
        return try SVG(parsing: data, options: options)
    }

    static func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

#endif
