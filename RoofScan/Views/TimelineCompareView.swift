//
//  TimelineCompareView.swift
//  RoofScan
//
//  17 — Timeline Compare. How roof health has trended across inspection rounds,
//  and where defects are accumulating.
//

import SwiftUI

struct TimelineCompareView: View {
    @EnvironmentObject private var store: RoofStore

    // Rounds oldest → newest for charting.
    private var series: [(date: Date, value: Int)] {
        store.project.rounds.sorted { $0.date < $1.date }.map { ($0.date, $0.healthAtTime) }
    }

    var body: some View {
        ScreenScaffold(title: "Timeline Compare", subtitle: "Health across inspections") {

            if series.count < 2 {
                CardView { EmptyStateView(icon: "chart.xyaxis.line", title: "Not enough data",
                                          message: "Complete at least two inspection rounds to compare how the roof is trending.") }
            } else {
                CardView {
                    SectionHeader(title: "Roof health", subtitle: "\(series.count) rounds", icon: "waveform.path.ecg")
                    HealthLineChart(points: series.map { Double($0.value) })
                        .frame(height: 160)
                    HStack {
                        Text("First: \(series.first!.value)%").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        Spacer()
                        let delta = series.last!.value - series.first!.value
                        Text("\(delta >= 0 ? "+" : "")\(delta)%")
                            .font(.rsBodyBold())
                            .foregroundColor(delta >= 0 ? Theme.ok : Theme.critical)
                        Spacer()
                        Text("Now: \(series.last!.value)%").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    }
                }
            }

            // Per-slope current health
            if !store.project.slopes.isEmpty {
                CardView {
                    SectionHeader(title: "Current slope health", icon: "square.3.layers.3d")
                    ForEach(store.project.slopes) { s in
                        let h = store.health.perSlope[s.id] ?? 100
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(s.name).font(.rsBody()).foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(h)%").font(.rsBodyBold()).foregroundColor(SeverityPalette.health(h))
                            }
                            ProgressBar(fraction: Double(h) / 100, tint: SeverityPalette.health(h), height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Defect accumulation from history
            CardView {
                SectionHeader(title: "Defect activity", icon: "chart.bar.fill")
                let added = store.project.history.filter { $0.type == .defectAdded }.count
                let grew = store.project.history.filter { $0.type == .defectGrew }.count
                let repaired = store.project.history.filter { $0.type == .defectRepaired }.count
                KeyValueRow(key: "Markers added", value: "\(added)", valueColor: Theme.signalOrange)
                KeyValueRow(key: "Defects grown", value: "\(grew)", valueColor: Theme.critical)
                KeyValueRow(key: "Repaired", value: "\(repaired)", valueColor: Theme.ok)
            }
        }
    }
}

// MARK: - Hand-drawn line chart (no Charts framework — iOS 15 safe)

struct HealthLineChart: View {
    let points: [Double]   // 0…100

    var body: some View {
        GeometryReader { geo in
            chart(in: geo.size)
        }
    }

    private func point(_ i: Int, in size: CGSize) -> CGPoint {
        let stepX = points.count > 1 ? size.width / CGFloat(points.count - 1) : size.width
        let y = size.height - CGFloat(points[i] / 100) * size.height
        return CGPoint(x: CGFloat(i) * stepX, y: y)
    }

    private func chart(in size: CGSize) -> some View {
        let w = size.width, h = size.height
        let stepX = points.count > 1 ? w / CGFloat(points.count - 1) : w

        return ZStack {
            // gridlines
            ForEach(0..<5, id: \.self) { i in
                Path { p in
                    let y = h * CGFloat(i) / 4
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(Theme.divider, lineWidth: 1)
            }
            // area
            Path { p in
                guard !points.isEmpty else { return }
                p.move(to: CGPoint(x: 0, y: h))
                for i in points.indices { p.addLine(to: point(i, in: size)) }
                p.addLine(to: CGPoint(x: CGFloat(points.count - 1) * stepX, y: h))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Theme.primary.opacity(0.35), .clear],
                                 startPoint: .top, endPoint: .bottom))
            // line
            Path { p in
                guard !points.isEmpty else { return }
                p.move(to: point(0, in: size))
                for i in points.indices.dropFirst() { p.addLine(to: point(i, in: size)) }
            }
            .stroke(Theme.ridge, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            // dots
            ForEach(points.indices, id: \.self) { i in
                Circle().fill(SeverityPalette.health(Int(points[i])))
                    .frame(width: 9, height: 9)
                    .position(point(i, in: size))
            }
        }
    }
}
