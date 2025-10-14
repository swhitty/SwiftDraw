//
//  LayerTree.Builder.Path.Arc.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 10/2/19.
//  Copyright 2020 WhileLoop Pty Ltd. All rights reserved.
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

//converts DOM.Path.Arc -> LayerTree.Path.Cubic

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(limits.upperBound, max(limits.lowerBound, self))
    }
}

private func almostEqual<T: FloatingPoint>(_ a: T, _ b: T) -> Bool {
    return a >= b.nextDown && a <= b.nextUp
}

func vectorAngle(ux: LayerTree.Float, uy: LayerTree.Float, vx: LayerTree.Float, vy: LayerTree.Float) -> LayerTree.Float {
    let sign: LayerTree.Float = (ux * vy - uy * vx) < 0.0 ? -1.0 : 1.0
    let dot  = (ux * vx + uy * vy).clamped(to: -1.0...1.0)
    return sign * acos(dot)
}

private extension LayerTree.Float {

    static var tau: LayerTree.Float {
        return .pi * 2
    }
}

private func getArcCenter(from origin: LayerTree.Point, to destination: LayerTree.Point,
                          fa: Bool, fs: Bool,
                          rx: LayerTree.Float, ry: LayerTree.Float,
                          sin_phi: LayerTree.Float,
                          cos_phi: LayerTree.Float) -> (point: LayerTree.Point, theta: LayerTree.Float, deltaT: LayerTree.Float) {

    let x1p =  cos_phi * (origin.x - destination.x) / 2 + sin_phi * (origin.y - destination.y) / 2
    let y1p = -sin_phi * (origin.x - destination.x) / 2 + cos_phi * (origin.y - destination.y) / 2

    let rx_sq  =  rx * rx
    let ry_sq  =  ry * ry
    let x1p_sq = x1p * x1p
    let y1p_sq = y1p * y1p

    var radicant = max((rx_sq * ry_sq) - (rx_sq * y1p_sq) - (ry_sq * x1p_sq), 0.0)
    let radicantSign: LayerTree.Float = fa == fs ? -1.0 : 1.0

    radicant /=  (rx_sq * y1p_sq) + (ry_sq * x1p_sq)
    radicant = radicant.squareRoot() * radicantSign

    let cxp = radicant *  rx / ry * y1p
    let cyp = radicant * -ry / rx * x1p

    let cx = cos_phi * cxp - sin_phi * cyp + (origin.x + destination.x) / 2
    let cy = sin_phi * cxp + cos_phi * cyp + (origin.y + destination.y) / 2

    let v1x =  (x1p - cxp) / rx
    let v1y =  (y1p - cyp) / ry
    let v2x = (-x1p - cxp) / rx
    let v2y = (-y1p - cyp) / ry

    let theta1 = vectorAngle(ux: 1, uy: 0, vx: v1x, vy: v1y);
    var delta_theta = vectorAngle(ux: v1x, uy: v1y, vx: v2x, vy: v2y);

    if (fs == false && delta_theta > 0) {
        delta_theta -= .tau;
    }
    if (fs == true && delta_theta < 0) {
        delta_theta += .tau;
    }

    return (point: LayerTree.Point(cx, cy), theta: theta1, deltaT: delta_theta)
}

private func approximateUnitArc(theta: LayerTree.Float, deltaT: LayerTree.Float) -> [LayerTree.Float] {
    let alpha = (4.0 / 3.0) * tan(deltaT / 4.0)

    let x1 = cos(theta)
    let y1 = sin(theta)
    let x2 = cos(theta + deltaT)
    let y2 = sin(theta + deltaT)

    return [x1,
            y1,
            x1 - y1 * alpha,
            y1 + x1 * alpha,
            x2 + y2 * alpha,
            y2 - x2 * alpha,
            x2,
            y2]
}


private func makePoint(x: LayerTree.Float, y: LayerTree.Float, rx: LayerTree.Float, ry: LayerTree.Float, cos_phi: LayerTree.Float, sin_phi: LayerTree.Float, center: LayerTree.Point) -> LayerTree.Point {

    let x1 = x * rx
    let y1 = y * ry

    let xp = cos_phi * x1 - sin_phi * y1
    let yp = sin_phi * x1 + cos_phi * y1

    return LayerTree.Point(xp + center.x, yp + center.y)
}

func makeCubic(from origin: LayerTree.Point, to destination: LayerTree.Point,
               large: Bool, sweep: Bool,
               rx: LayerTree.Float, ry: LayerTree.Float,
               rotation: LayerTree.Float) -> [(p: LayerTree.Point, cp1: LayerTree.Point, cp2: LayerTree.Point)] {

    let sin_phi = sin(rotation * .tau / 360.0)
    let cos_phi = cos(rotation * .tau / 360.0)

    let x1p =  cos_phi * (origin.x - destination.x) / 2.0 + sin_phi * (origin.y - destination.y) / 2.0
    let y1p = -sin_phi * (origin.x - destination.x) / 2.0 + cos_phi * (origin.y - destination.y) / 2.0

    if almostEqual(x1p, 0.0) && almostEqual(y1p, 0.0) {
        return [];
    }

    if almostEqual(rx, 0.0) || almostEqual(ry, 0.0) {
        return [];
    }

    var rx1 = abs(rx)
    var ry1 = abs(ry)

    let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if (lambda > 1.0) {
        let lambdaSquareRoot = lambda.squareRoot()
        rx1 *= lambdaSquareRoot
        ry1 *= lambdaSquareRoot
    }

    let cc = getArcCenter(from: origin, to: destination, fa: large, fs: sweep, rx: rx, ry: ry, sin_phi: sin_phi, cos_phi: cos_phi)

    var result = [[LayerTree.Float]]()

    guard let totalSegments = Int(exactly: ceil(abs(cc.deltaT) / (LayerTree.Float.tau / 4.0))) else {
        return []
    }
    let segments = max(totalSegments, 1)
    let deltaT = cc.deltaT / LayerTree.Float(segments)

    var theta1 = cc.theta

    for _ in 0..<segments {
        let unit = approximateUnitArc(theta: theta1, deltaT: deltaT)
        result.append(unit)
        theta1 += deltaT
    }

    return result.map {
        let cp1 = makePoint(x: $0[2], y: $0[3], rx: rx1, ry: ry1, cos_phi: cos_phi, sin_phi: sin_phi, center: cc.point)
        let cp2 = makePoint(x: $0[4], y: $0[5], rx: rx1, ry: ry1, cos_phi: cos_phi, sin_phi: sin_phi, center: cc.point)
        let p = makePoint(x: $0[6], y: $0[7], rx: rx1, ry: ry1, cos_phi: cos_phi, sin_phi: sin_phi, center: cc.point)

        return (p: p, cp1: cp1, cp2: cp2)
    }
}
