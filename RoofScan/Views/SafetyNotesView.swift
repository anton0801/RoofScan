//
//  SafetyNotesView.swift
//  RoofScan
//
//  11 — Safety Notes. A go/no-go weather self-check, a pre-climb checklist, and
//  roof-specific hazard flags. Climbing must always be safe.
//

import SwiftUI

struct SafetyNotesView: View {
    @EnvironmentObject private var store: RoofStore

    @State private var isDry = true
    @State private var isCalm = true
    @State private var checked: Set<String> = []

    private let checklist = [
        "Harness + anchor point rigged",
        "Non-slip footwear",
        "Ladder at ~75° and tied off",
        "A second person on the ground",
        "No overhead power lines nearby",
        "Good daylight, not near dusk",
        "Tools secured / tethered"
    ]

    private var noGo: Bool { !isDry || !isCalm }

    var body: some View {
        ScreenScaffold(title: "Safety Notes", subtitle: "Before you climb") {

            if noGo {
                CardView(tint: Theme.critical.opacity(0.16)) {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.raised.fill").foregroundColor(Theme.critical)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DO NOT CLIMB").font(.rsHeadline()).foregroundColor(Theme.critical)
                            Text("Wet or windy conditions — inspect from the ground or with a drone.")
                                .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }

            CardView {
                SectionHeader(title: "Conditions", icon: "cloud.sun.fill")
                ToggleRow(title: "Dry — roof is not wet/icy", icon: "sun.max.fill", isOn: $isDry)
                Divider().background(Theme.divider)
                ToggleRow(title: "Calm — little or no wind", icon: "wind", isOn: $isCalm)
            }

            CardView {
                SectionHeader(title: "Pre-climb checklist", subtitle: "\(checked.count)/\(checklist.count) done", icon: "checklist")
                ForEach(checklist, id: \.self) { item in
                    CheckRow(title: item, checked: checked.contains(item)) {
                        if checked.contains(item) { checked.remove(item) } else { checked.insert(item) }
                    }
                    if item != checklist.last { Divider().background(Theme.divider) }
                }
            }

            if !roofFlags.isEmpty {
                CardView {
                    SectionHeader(title: "This roof's hazards", icon: "exclamationmark.triangle.fill")
                    ForEach(roofFlags, id: \.self) { flag in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(Theme.amber)
                                .font(.system(size: 13))
                            Text(flag).font(.rsBody()).foregroundColor(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            CardView {
                SectionHeader(title: "Check from below / drone", icon: "binoculars.fill")
                ForEach(["Chimney & wall flashings", "Ridge line & caps", "Valley centers", "Any area you can't reach safely"], id: \.self) { s in
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill").foregroundColor(Theme.ridge).font(.system(size: 12))
                        Text(s).font(.rsBody()).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var roofFlags: [String] {
        var flags: [String] = []
        if store.project.slopes.contains(where: { $0.pitchDegrees >= 35 }) {
            flags.append("Steep slopes (≥35°) — high slip risk, use roof anchors.")
        }
        if store.project.climateLoads.contains(.snow) {
            flags.append("Snow/ice climate — surfaces stay slick; avoid frosty mornings.")
        }
        if store.project.climateLoads.contains(.coastalSalt) {
            flags.append("Coastal salt — corroded fasteners may give way underfoot.")
        }
        if store.project.covering == .metal {
            flags.append("Metal covering is slippery when damp — wait for full dry.")
        }
        if store.project.covering == .slate || store.project.covering == .tile {
            flags.append("Slate/tile can crack under foot — walk battens, spread load.")
        }
        return flags
    }
}
