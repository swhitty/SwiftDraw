//
//  LayerTree.GradientUnitsTests.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 15/11/26.
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

@testable import SwiftDraw
import SwiftDrawDOM
import Foundation
import Testing

/// objectBoundingBox gradients are drawn in the unit space of the shape's bounding box,
/// with gradientTransform applied within it.
struct LayerTreeGradientUnitsTests {

    typealias Command = RendererCommand<LayerTreeTypes>

    @Test
    func radialGradientIsDrawnInBoundingBoxSpace() throws {
        let commands = try makeCommands(
            #"""
            <radialGradient id="g"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></radialGradient>
            <rect x="10" y="20" width="200" height="50" fill="url(#g)" />
            """#
        )

        #expect(
            commands.gradientSteps == [
                .translate(10, 20),
                .scale(200, 50),
                .radial(LayerTree.Point(0.5, 0.5), 0, LayerTree.Point(0.5, 0.5), 0.5),
            ]
        )
    }

    @Test
    func linearGradientIsDrawnInBoundingBoxSpace() throws {
        let commands = try makeCommands(
            #"""
            <linearGradient id="g" x2="1" y2="1"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></linearGradient>
            <rect x="10" y="20" width="200" height="50" fill="url(#g)" />
            """#
        )

        #expect(
            commands.gradientSteps == [
                .translate(10, 20),
                .scale(200, 50),
                .linear(LayerTree.Point(0, 0), LayerTree.Point(1, 1)),
            ]
        )
    }

    @Test
    func gradientTransformIsAppliedWithinBoundingBox() throws {
        let commands = try makeCommands(
            #"""
            <radialGradient id="g" gradientTransform="scale(0.5 1)"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></radialGradient>
            <rect x="10" y="20" width="200" height="50" fill="url(#g)" />
            """#
        )

        #expect(
            commands.gradientSteps == [
                .translate(10, 20),
                .scale(200, 50),
                .scale(0.5, 1),
                .radial(LayerTree.Point(0.5, 0.5), 0, LayerTree.Point(0.5, 0.5), 0.5),
            ]
        )
    }

    @Test
    func userSpaceGradientIsNotScaled() throws {
        let commands = try makeCommands(
            #"""
            <radialGradient id="g" gradientUnits="userSpaceOnUse" cx="50" cy="40" r="30" gradientTransform="translate(5 0)">
                <stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" />
            </radialGradient>
            <rect x="10" y="20" width="200" height="50" fill="url(#g)" />
            """#
        )

        #expect(
            commands.gradientSteps == [
                .translate(5, 0),
                .radial(LayerTree.Point(50, 40), 0, LayerTree.Point(50, 40), 30),
            ]
        )
    }

    @Test
    func strokeGradientUsesShapeBoundingBox() throws {
        let commands = try makeCommands(
            #"""
            <linearGradient id="g"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></linearGradient>
            <polyline points="10,20 210,20 210,70" fill="none" stroke="url(#g)" stroke-width="4" />
            """#
        )

        #expect(
            commands.gradientSteps == [
                .translate(10, 20),
                .scale(200, 50),
                .linear(LayerTree.Point(0, 0), LayerTree.Point(1, 0)),
            ]
        )
    }

    @Test(arguments: [
        #"<line x1="10" y1="20" x2="210" y2="20" stroke="url(#g)" stroke-width="4" />"#,
        #"<line x1="10" y1="20" x2="10" y2="80" stroke="url(#g)" stroke-width="4" />"#,
    ])
    func boundingBoxWithoutAreaIgnoresGradient(shape: String) throws {
        let commands = try makeCommands(
            #"""
            <linearGradient id="g"><stop offset="0" stop-color="red" /><stop offset="1" stop-color="blue" /></linearGradient>
            \#(shape)
            """#
        )

        #expect(commands.gradientSteps.isEmpty)
    }

    func makeCommands(_ contents: String) throws -> [Command] {
        let svg = try DOM.SVG.parse(
            xml: #"""
                <svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
                    \#(contents)
                </svg>
                """#
        )
        let layer = LayerTree.Builder(svg: svg).makeLayer()
        let generator = LayerTree.CommandGenerator(provider: LayerTreeProvider(), size: .zero, options: .default)
        return generator.renderCommands(for: layer, colorConverter: .default)
    }
}

private enum GradientStep: Equatable {
    case translate(LayerTree.Float, LayerTree.Float)
    case scale(LayerTree.Float, LayerTree.Float)
    case linear(LayerTree.Point, LayerTree.Point)
    case radial(LayerTree.Point, LayerTree.Float, LayerTree.Point, LayerTree.Float)
}

private extension Array where Element == RendererCommand<LayerTreeTypes> {

    // the transforms and draws between the gradient's clip and its draw call
    var gradientSteps: [GradientStep] {
        guard
            let clip = firstIndex(where: {
                if case .setClip = $0 { return true }
                if case .clipStrokeOutline = $0 { return true }
                return false
            })
        else { return [] }
        var steps = [GradientStep]()
        for command in self[clip...] {
            switch command {
            case let .translate(tx, ty):
                steps.append(.translate(tx, ty))
            case let .scale(sx, sy):
                steps.append(.scale(sx, sy))
            case let .drawLinearGradient(_, from, to):
                steps.append(.linear(from, to))
                return steps
            case let .drawRadialGradient(_, startCenter, startRadius, endCenter, endRadius):
                steps.append(.radial(startCenter, startRadius, endCenter, endRadius))
                return steps
            case .popState:
                return []
            default:
                continue
            }
        }
        return []
    }
}
