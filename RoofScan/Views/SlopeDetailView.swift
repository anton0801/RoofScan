//
//  SlopeDetailView.swift
//  RoofScan
//
//  12 — Slope Detail. Everything about one slope: stats, its defects, photos,
//  and change history.
//

import SwiftUI

struct SlopeDetailView: View {
    @EnvironmentObject private var store: RoofStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode

    let slopeID: UUID
    @State private var showEdit = false
    @State private var showAddDefect = false
    @State private var selectedDefect: Defect?
    @State private var showDelete = false

    private var slope: Slope? { store.project.slopes.first { $0.id == slopeID } }

    var body: some View {
        Group {
            if let slope = slope {
                ScreenScaffold(title: slope.name, subtitle: "\(slope.orientation.label)-facing · \(Int(slope.pitchDegrees))°") {
                    statsCard(slope)
                    nodesCard(slope)
                    defectsSection(slope)
                    photosSection(slope)
                    historySection(slope)

                    DangerButton(title: "Delete slope", icon: "trash.fill") { showDelete = true }
                        .padding(.top, 6)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showEdit = true } label: { Image(systemName: "square.and.pencil") }
                    }
                }
                .sheet(isPresented: $showEdit) { AddSlopeView(editing: slope) }
                .sheet(isPresented: $showAddDefect) { AddDefectView(preselectedSlopeID: slopeID) }
                .sheet(item: $selectedDefect) { d in DefectDetailView(defectID: d.id) }
                .alert(isPresented: $showDelete) {
                    Alert(title: Text("Delete slope?"),
                          message: Text("This removes the slope and all its markers."),
                          primaryButton: .destructive(Text("Delete")) {
                              store.deleteSlope(slope); presentationMode.wrappedValue.dismiss()
                          },
                          secondaryButton: .cancel())
                }
            } else {
                ScreenScaffold(title: "Slope") {
                    EmptyStateView(icon: "questionmark.square.dashed", title: "Removed",
                                   message: "This slope no longer exists.")
                }
            }
        }
    }

    private func statsCard(_ s: Slope) -> some View {
        let h = store.health.perSlope[s.id] ?? 100
        return CardView {
            HStack {
                HealthRing(percent: h, size: 84, lineWidth: 9)
                VStack(alignment: .leading, spacing: 6) {
                    KeyValueRow(key: "Size", value: "\(settings.length(s.length)) × \(settings.length(s.width))")
                    KeyValueRow(key: "Sloped area", value: settings.area(s.area), valueColor: Theme.amber)
                    KeyValueRow(key: "Pitch", value: "\(Int(s.pitchDegrees))° · \(Int(s.pitchPercent))%")
                    KeyValueRow(key: "Drains toward", value: s.drainageDirection.label, valueColor: Theme.ridge)
                }
            }
        }
    }

    private func nodesCard(_ s: Slope) -> some View {
        CardView {
            SectionHeader(title: "Perimeter nodes", icon: "point.3.connected.trianglepath.dotted")
            if s.nodeTypes.isEmpty {
                Text("No nodes recorded.").font(.rsCaption()).foregroundColor(Theme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(s.nodeTypes) { n in
                        HStack(spacing: 6) {
                            Image(systemName: n.icon).foregroundColor(Theme.ridge).font(.system(size: 12))
                            Text(n.label).font(.rsCaption()).foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSoft))
                    }
                }
            }
        }
    }

    private func defectsSection(_ s: Slope) -> some View {
        let defects = store.project.defects(on: s.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Defects", subtitle: "\(defects.count) total", icon: "exclamationmark.triangle.fill")
                Spacer()
                Button { showAddDefect = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.primary).font(.system(size: 22))
                }
            }
            if defects.isEmpty {
                Text("No defects on this slope yet.").font(.rsCaption()).foregroundColor(Theme.textSecondary)
            } else {
                ForEach(defects.sorted { $0.severity > $1.severity }) { d in
                    Button { selectedDefect = d } label: { DefectRow(defect: d, slopeName: s.name) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func photosSection(_ s: Slope) -> some View {
        let photos = store.project.photos.filter { $0.slopeID == s.id }
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Photos", icon: "photo.on.rectangle.angled")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { p in
                            VStack(spacing: 4) {
                                PhotoThumb(filename: p.filename, size: 96, corner: 12)
                                Text(p.caption).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                                    .lineLimit(1).frame(width: 96)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historySection(_ s: Slope) -> some View {
        let defectIDs = Set(store.project.defects(on: s.id).map { $0.id })
        let events = store.project.history.filter { ev in
            ev.relatedID == s.id || (ev.relatedID.map { defectIDs.contains($0) } ?? false)
        }
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "History", icon: "clock.arrow.circlepath")
                ForEach(events.prefix(8)) { ev in
                    HStack(spacing: 10) {
                        Image(systemName: ev.type.icon).foregroundColor(ev.type.color).font(.system(size: 13))
                        Text(ev.summary).font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }
}
