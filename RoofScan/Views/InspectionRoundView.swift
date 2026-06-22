//
//  InspectionRoundView.swift
//  RoofScan
//
//  14 — Inspection Round. Walk every slope and joint, tick them off, capture any
//  new defects, then log the round (snapshots health for timeline compare).
//

import SwiftUI

struct InspectionRoundView: View {
    @EnvironmentObject private var store: RoofStore

    @State private var checkedSlopes: Set<UUID> = []
    @State private var checkedFlashings: Set<UUID> = []
    @State private var notes = ""
    @State private var showAddDefect = false
    @State private var savedFlash = false

    private var total: Int { store.project.slopes.count + store.project.flashings.count }
    private var done: Int { checkedSlopes.count + checkedFlashings.count }

    var body: some View {
        ScreenScaffold(title: "Inspection Round", subtitle: "Walk it all, tick it off") {

            CardView {
                HStack {
                    SectionHeader(title: "Progress", subtitle: "\(done)/\(max(total,1)) checked", icon: "checklist")
                    Spacer()
                    Text("\(Int(Double(done) / Double(max(total, 1)) * 100))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.primary)
                }
                ProgressBar(fraction: total == 0 ? 0 : Double(done) / Double(total), tint: Theme.primary)
            }

            if store.project.slopes.isEmpty && store.project.flashings.isEmpty {
                CardView { EmptyStateView(icon: "checklist", title: "Nothing to inspect",
                                          message: "Add slopes and joints, then run a round.") }
            }

            if !store.project.slopes.isEmpty {
                CardView {
                    SectionHeader(title: "Slopes", icon: "square.3.layers.3d")
                    ForEach(store.project.slopes) { s in
                        CheckRow(title: s.name,
                                 subtitle: "\(store.project.activeDefects(on: s.id).count) active defects",
                                 checked: checkedSlopes.contains(s.id)) {
                            toggle(&checkedSlopes, s.id)
                        }
                        if s.id != store.project.slopes.last?.id { Divider().background(Theme.divider) }
                    }
                }
            }

            if !store.project.flashings.isEmpty {
                CardView {
                    SectionHeader(title: "Joints", icon: "building.2.fill")
                    ForEach(store.project.flashings) { f in
                        CheckRow(title: f.label.isEmpty ? f.location.label : f.label,
                                 subtitle: f.condition.label,
                                 checked: checkedFlashings.contains(f.id)) {
                            toggle(&checkedFlashings, f.id)
                        }
                        if f.id != store.project.flashings.last?.id { Divider().background(Theme.divider) }
                    }
                }
            }

            LabeledNote(label: "Round notes", text: $notes)

            VStack(spacing: 10) {
                SecondaryButton(title: "Found something — add marker", icon: "mappin.and.ellipse") {
                    showAddDefect = true
                }
                PrimaryButton(title: savedFlash ? "Round logged ✓" : "Complete round", icon: "checkmark.seal.fill",
                              enabled: total > 0) {
                    complete()
                }
            }

            if !store.project.rounds.isEmpty {
                SectionHeader(title: "Past rounds", icon: "clock.arrow.circlepath")
                ForEach(store.project.rounds) { r in
                    CardView {
                        KeyValueRow(key: dateString(r.date), value: "Health \(r.healthAtTime)%",
                                    valueColor: SeverityPalette.health(r.healthAtTime))
                        Text("\(r.checkedSlopeIDs.count) slopes · \(r.checkedFlashingIDs.count) joints checked")
                            .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        if !r.notes.isEmpty {
                            Text(r.notes).font(.rsCaption()).foregroundColor(Theme.textDisabled)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddDefect) { AddDefectView(preselectedSlopeID: store.project.slopes.first?.id) }
    }

    private func toggle(_ set: inout Set<UUID>, _ id: UUID) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func complete() {
        let round = InspectionRound(checkedSlopeIDs: Array(checkedSlopes),
                                    checkedFlashingIDs: Array(checkedFlashings),
                                    notes: notes)
        store.addRound(round)
        withAnimation { savedFlash = true }
        checkedSlopes = []; checkedFlashings = []; notes = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { savedFlash = false }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
