//
//  IsometricProjection.swift
//  RoofScan
//
//  Pure, deterministic isometric layout. Turns the slopes array into screen-space
//  quads (data-driven — no hardcoded geometry), lifting the ridge edge by pitch and
//  fitting the whole roof into the available rect.
//

import SwiftUI
import CoreGraphics

// MARK: - 2:1 isometric projection

struct IsoProjection {
    var tileW: CGFloat = 14
    var tileH: CGFloat = 7
    func project(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - p.y) * tileW, y: (p.x + p.y) * tileH)
    }
}

// MARK: - Laid-out slope (absolute screen coords)

struct SlopeLayout: Identifiable {
    let id: UUID
    let slope: Slope
    let ridgeLeft: CGPoint
    let ridgeRight: CGPoint
    let eaveRight: CGPoint
    let eaveLeft: CGPoint

    var corners: [CGPoint] { [ridgeLeft, ridgeRight, eaveRight, eaveLeft] }

    var centroid: CGPoint {
        CGPoint(x: corners.map { $0.x }.reduce(0, +) / 4,
                y: corners.map { $0.y }.reduce(0, +) / 4)
    }

    /// Bilinear position for a normalized defect point (x across, y ridge→eave).
    func point(x: Double, y: Double) -> CGPoint {
        let cx = CGFloat(max(0, min(1, x))), cy = CGFloat(max(0, min(1, y)))
        let top = lerp(ridgeLeft, ridgeRight, cx)
        let bottom = lerp(eaveLeft, eaveRight, cx)
        return lerp(top, bottom, cy)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

// MARK: - Layout engine

enum RoofLayoutEngine {

    static func layout(slopes: [Slope], in rect: CGRect, padding: CGFloat = 30) -> [SlopeLayout] {
        guard !slopes.isEmpty, rect.width > 1, rect.height > 1 else { return [] }
        let iso = IsoProjection()
        let spread: CGFloat = 2.5

        var orientCount: [Orientation: Int] = [:]
        var raw: [(Slope, [CGPoint])] = []

        for slope in slopes {
            let o = slope.orientation
            let idx = orientCount[o, default: 0]
            orientCount[o] = idx + 1

            let az = CGVector(dx: o.azimuth.dx, dy: o.azimuth.dy)   // down-slope
            let side = CGVector(dx: az.dy, dy: -az.dx)              // perpendicular
            let up = CGVector(dx: -az.dx, dy: -az.dy)               // toward ridge

            let halfRun = CGFloat(max(1, slope.length)) / 2
            let halfWid = CGFloat(max(1, slope.width)) / 2

            // Stack additional same-orientation slopes along the side axis.
            let stack = CGFloat(idx) * (CGFloat(max(1, slope.width)) + 1.4)
            let center = CGPoint(x: az.dx * (spread + halfRun) + side.dx * stack,
                                 y: az.dy * (spread + halfRun) + side.dy * stack)

            func corner(run runSign: CGFloat, side sideSign: CGFloat) -> CGPoint {
                CGPoint(x: center.x + up.dx * halfRun * runSign + side.dx * halfWid * sideSign,
                        y: center.y + up.dy * halfRun * runSign + side.dy * halfWid * sideSign)
            }

            let pRidgeL = iso.project(corner(run: 1, side: -1))
            let pRidgeR = iso.project(corner(run: 1, side: 1))
            let pEaveR  = iso.project(corner(run: -1, side: 1))
            let pEaveL  = iso.project(corner(run: -1, side: -1))

            // Raise the ridge edge on screen by pitch → slanted plane look.
            let lift = CGFloat(sin(min(max(slope.pitchDegrees, 0), 75) * .pi / 180)) * halfRun * iso.tileH * 2.2
            let ridgeL = CGPoint(x: pRidgeL.x, y: pRidgeL.y - lift)
            let ridgeR = CGPoint(x: pRidgeR.x, y: pRidgeR.y - lift)

            raw.append((slope, [ridgeL, ridgeR, pEaveR, pEaveL]))
        }

        // Fit the bounding box of all points into the rect, centered.
        let all = raw.flatMap { $0.1 }
        let minX = all.map { $0.x }.min() ?? 0
        let maxX = all.map { $0.x }.max() ?? 1
        let minY = all.map { $0.y }.min() ?? 0
        let maxY = all.map { $0.y }.max() ?? 1
        let w = max(1, maxX - minX), h = max(1, maxY - minY)
        let availW = max(1, rect.width - padding * 2)
        let availH = max(1, rect.height - padding * 2)
        let scale = min(availW / w, availH / h)
        let offX = rect.minX + padding + (availW - w * scale) / 2
        let offY = rect.minY + padding + (availH - h * scale) / 2

        func fit(_ p: CGPoint) -> CGPoint {
            CGPoint(x: offX + (p.x - minX) * scale, y: offY + (p.y - minY) * scale)
        }

        return raw.map { item in
            let c = item.1
            return SlopeLayout(id: item.0.id, slope: item.0,
                               ridgeLeft: fit(c[0]), ridgeRight: fit(c[1]),
                               eaveRight: fit(c[2]), eaveLeft: fit(c[3]))
        }
    }
}

// MARK: - Slope quad shape (absolute coords)

struct SlopeQuad: Shape {
    let corners: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard corners.count == 4 else { return p }
        p.move(to: corners[0])
        p.addLine(to: corners[1])
        p.addLine(to: corners[2])
        p.addLine(to: corners[3])
        p.closeSubpath()
        return p
    }
}

// MARK: - Single edge line

struct EdgeLine: Shape {
    let a: CGPoint
    let b: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }
}
