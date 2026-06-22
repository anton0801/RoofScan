//
//  RoofMapCanvas.swift
//  RoofScan
//
//  Renders the isometric roof: slope planes, ridge/valley structural lines,
//  down-slope drainage arrows, and pulsing heat markers. Pinch to zoom,
//  drag to pan, double-tap to reset.
//

import SwiftUI

struct RoofMapCanvas: View {
    let slopes: [Slope]
    let defects: [Defect]
    let perSlopeHealth: [UUID: Int]
    var onMarkerTap: (Defect) -> Void
    var onSlopeTap: ((Slope) -> Void)? = nil

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let layouts = RoofLayoutEngine.layout(
                slopes: slopes, in: CGRect(origin: .zero, size: geo.size))

            ZStack {
                ForEach(layouts) { l in
                    slopeView(l)
                }
                ForEach(defects) { d in
                    if let l = layouts.first(where: { $0.id == d.slopeID }) {
                        let pos = l.point(x: d.x, y: d.y)
                        PulsingMarker(color: markerColor(d), pulse: d.status == .active)
                            .position(pos)
                            .onTapGesture { onMarkerTap(d) }
                    }
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { v in scale = min(3, max(0.6, lastScale * v)) }
                        .onEnded { _ in lastScale = scale },
                    DragGesture()
                        .onChanged { v in
                            offset = CGSize(width: lastOffset.width + v.translation.width,
                                            height: lastOffset.height + v.translation.height)
                        }
                        .onEnded { _ in lastOffset = offset }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Slope plane + structure

    @ViewBuilder
    private func slopeView(_ l: SlopeLayout) -> some View {
        let health = perSlopeHealth[l.slope.id] ?? 100
        ZStack {
            // Plane fill
            SlopeQuad(corners: l.corners)
                .fill(LinearGradient(colors: [Theme.cardHover, Theme.bgDepth],
                                     startPoint: .top, endPoint: .bottom))
            // Health tint overlay
            SlopeQuad(corners: l.corners)
                .fill(SeverityPalette.health(health).opacity(0.16))
            // Plane outline
            SlopeQuad(corners: l.corners)
                .stroke(Theme.border, lineWidth: 1)

            // Ridge edge (glowing structural line)
            EdgeLine(a: l.ridgeLeft, b: l.ridgeRight)
                .stroke(Theme.ridge, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rsGlow(Theme.ridge.opacity(0.6), radius: 5)

            // Valley side-edges when present
            if l.slope.nodeTypes.contains(.valley) {
                EdgeLine(a: l.ridgeLeft, b: l.eaveLeft)
                    .stroke(Theme.valley, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                EdgeLine(a: l.ridgeRight, b: l.eaveRight)
                    .stroke(Theme.valley, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            // Drainage arrow (ridge-mid → eave-mid)
            drainageArrow(l)

            // Slope label
            Text(l.slope.name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Capsule().fill(Theme.bg.opacity(0.7)))
                .position(l.centroid)
                .allowsHitTesting(onSlopeTap != nil)
                .onTapGesture { onSlopeTap?(l.slope) }
        }
    }

    private func drainageArrow(_ l: SlopeLayout) -> some View {
        let ridgeMid = CGPoint(x: (l.ridgeLeft.x + l.ridgeRight.x) / 2,
                               y: (l.ridgeLeft.y + l.ridgeRight.y) / 2)
        let eaveMid = CGPoint(x: (l.eaveLeft.x + l.eaveRight.x) / 2,
                              y: (l.eaveLeft.y + l.eaveRight.y) / 2)
        let dx = eaveMid.x - ridgeMid.x, dy = eaveMid.y - ridgeMid.y
        let angle = atan2(dy, dx)
        let pos = CGPoint(x: ridgeMid.x + dx * 0.6, y: ridgeMid.y + dy * 0.6)
        return Image(systemName: "arrow.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Theme.valley)
            .rotationEffect(.radians(angle - .pi / 2))
            .position(pos)
            .opacity(0.85)
    }

    // MARK: - Marker color

    private func markerColor(_ d: Defect) -> Color {
        switch d.status {
        case .repaired:   return Theme.ok.opacity(0.7)
        case .inProgress: return Theme.inProgress
        case .active:     return SeverityPalette.color(severity: d.severity)
        }
    }
}
