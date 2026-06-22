//
//  RoofMapView.swift
//  RoofScan
//
//  01 — Roof Map (main). Isometric slope map with heat-coded markers, a health
//  summary, and quick actions (Add Slope / Add Marker / Trace Leak).
//

import SwiftUI

struct RoofMapView: View {
    @EnvironmentObject private var store: RoofStore

    @State private var showAddSlope = false
    @State private var showAddDefect = false
    @State private var selectedDefect: Defect?
    @State private var pushSlope: Slope?
    @State private var slopeLinkActive = false
    @State private var traceActive = false

    var body: some View {
        ScreenScaffold(title: "Roof Map", subtitle: store.project.covering.label + " · " + store.project.roofType.label) {

            summaryCard

            // Map
            if store.project.slopes.isEmpty {
                CardView {
                    EmptyStateView(icon: "square.3.layers.3d.down.right",
                                   title: "No slopes yet",
                                   message: "Draw your first roof slope to start placing damage markers.",
                                   actionTitle: "Add Slope") { showAddSlope = true }
                }
            } else {
                CardView(padding: 6) {
                    RoofMapCanvas(slopes: store.project.slopes,
                                  defects: store.project.defects,
                                  perSlopeHealth: store.health.perSlope,
                                  onMarkerTap: { selectedDefect = $0 },
                                  onSlopeTap: { pushSlope = $0; slopeLinkActive = true })
                        .frame(height: 320)
                }
                legend
            }

            // Quick actions
            HStack(spacing: 12) {
                QuickActionTile(icon: "square.badge.plus", title: "Add Slope", tint: Theme.primary) {
                    showAddSlope = true
                }
                QuickActionTile(icon: "mappin.and.ellipse", title: "Add Marker", tint: Theme.amber) {
                    showAddDefect = true
                }
                QuickActionTile(icon: "drop.degreesign.fill", title: "Trace Leak", tint: Theme.ridge) {
                    traceActive = true
                }
            }

            if !store.project.defects.isEmpty {
                SectionHeader(title: "Markers", subtitle: "\(store.project.activeDefectCount) active", icon: "exclamationmark.triangle.fill")
                ForEach(store.project.defects.sorted { $0.severity > $1.severity }) { d in
                    Button { selectedDefect = d } label: { DefectRow(defect: d, slopeName: store.slopeName(d.slopeID)) }
                        .buttonStyle(PressableStyle())
                }
            }

            // Hidden navigation links
            NavigationLink(destination: traceDestination, isActive: $traceActive) { EmptyView() }.hidden()
            NavigationLink(destination: slopeDestination, isActive: $slopeLinkActive) { EmptyView() }.hidden()
        }
        .sheet(isPresented: $showAddSlope) { AddSlopeView() }
        .sheet(isPresented: $showAddDefect) { AddDefectView(preselectedSlopeID: store.project.slopes.first?.id) }
        .sheet(item: $selectedDefect) { d in DefectDetailView(defectID: d.id) }
    }

    private var traceDestination: some View { LeakTraceView() }
    @ViewBuilder private var slopeDestination: some View {
        if let s = pushSlope { SlopeDetailView(slopeID: s.id) } else { EmptyView() }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let health = store.health
        return CardView {
            HStack(spacing: 16) {
                HealthRing(percent: health.overall, size: 104, lineWidth: 11)
                VStack(alignment: .leading, spacing: 10) {
                    StatRow(icon: "exclamationmark.triangle.fill",
                            label: "Active defects",
                            value: "\(store.project.activeDefectCount)",
                            tint: store.project.activeDefectCount == 0 ? Theme.ok : Theme.signalOrange)
                    StatRow(icon: "arrow.down.right.circle.fill",
                            label: "Worst slope",
                            value: store.worstSlope?.name ?? "—",
                            tint: Theme.amber)
                    StatRow(icon: "calendar.badge.clock",
                            label: "Remaining life",
                            value: String(format: "%.0f yr", store.serviceLife.remainingYears),
                            tint: store.serviceLife.tier.color)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([("Low", Theme.ok), ("Med", Theme.amber), ("High", Theme.signalOrange), ("Critical", Theme.critical)], id: \.0) { item in
                HStack(spacing: 5) {
                    Circle().fill(item.1).frame(width: 9, height: 9)
                    Text(item.0).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Rows

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = Theme.primary
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(tint).font(.system(size: 13, weight: .bold)).frame(width: 18)
            Text(label).font(.rsCaption()).foregroundColor(Theme.textSecondary)
            Spacer(minLength: 6)
            Text(value).font(.rsBodyBold()).foregroundColor(Theme.textPrimary).lineLimit(1)
        }
    }
}

struct DefectRow: View {
    let defect: Defect
    let slopeName: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(SeverityPalette.color(severity: defect.severity).opacity(0.18)).frame(width: 42, height: 42)
                Image(systemName: defect.type.icon)
                    .foregroundColor(SeverityPalette.color(severity: defect.severity))
                    .font(.system(size: 16, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(defect.type.label).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                Text(slopeName).font(.rsCaption()).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                SeverityBadge(severity: defect.severity)
                StatusBadge(status: defect.status)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}
