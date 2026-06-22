//
//  StormCheckView.swift
//  RoofScan
//
//  08 — Storm Check. Fast post-storm walk of vulnerable nodes, stamped with the
//  storm date. Optionally schedules a 3-day re-check reminder.
//

import SwiftUI

struct StormCheckView: View {
    @EnvironmentObject private var store: RoofStore
    @Environment(\.presentationMode) private var presentationMode

    private let stormTypes = ["High wind", "Hail", "Heavy rain", "Snow / ice", "Falling debris"]
    private let baseItems = [
        "Lifted or missing shingles / tiles",
        "Displaced ridge caps",
        "Flashing pulled loose",
        "New interior stains / drips",
        "Gutters torn or clogged",
        "Debris piled on roof",
        "Dented metal, vents or skylights"
    ]

    @State private var stormType = "High wind"
    @State private var checked: Set<String> = []
    @State private var observations = ""
    @State private var savedFlash = false

    var body: some View {
        ScreenScaffold(title: "Storm Check", subtitle: "Fast post-storm walk-around") {
            InfoBanner(text: "Don't climb in wind or rain — inspect from the ground or with a drone first.",
                       icon: "wind", tint: Theme.signalOrange)

            VStack(alignment: .leading, spacing: 8) {
                Text("Storm type").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(stormTypes, id: \.self) { t in
                        Chip(label: t, selected: stormType == t) { stormType = t }
                    }
                }
            }

            CardView {
                SectionHeader(title: "Vulnerable nodes", subtitle: "\(checked.count)/\(baseItems.count) checked", icon: "checklist")
                ForEach(baseItems, id: \.self) { item in
                    CheckRow(title: item, checked: checked.contains(item)) {
                        if checked.contains(item) { checked.remove(item) } else { checked.insert(item) }
                    }
                    if item != baseItems.last { Divider().background(Theme.divider) }
                }
            }

            LabeledNote(label: "Observations", text: $observations)

            VStack(spacing: 10) {
                PrimaryButton(title: savedFlash ? "Logged ✓" : "Log storm check", icon: "tray.and.arrow.down.fill") {
                    logStorm()
                }
                SecondaryButton(title: "Add a new defect now", icon: "mappin.and.ellipse") {
                    showAddDefect = true
                }
                SecondaryButton(title: "Schedule 3-day re-check", icon: "bell.badge.fill") {
                    schedulePostStorm()
                }
            }

            if !store.project.storms.isEmpty {
                SectionHeader(title: "Past storm checks", icon: "clock.arrow.circlepath")
                ForEach(store.project.storms) { s in
                    CardView {
                        KeyValueRow(key: s.stormType, value: dateString(s.date), valueColor: Theme.textSecondary)
                        if !s.observations.isEmpty {
                            Text(s.observations).font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        }
                        Text("\(s.checkedItems.count) items reviewed").font(.system(size: 11)).foregroundColor(Theme.textDisabled)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddDefect) { AddDefectView(preselectedSlopeID: store.project.slopes.first?.id) }
    }

    @State private var showAddDefect = false

    private func logStorm() {
        let storm = StormCheck(stormType: stormType, observations: observations,
                               checkedItems: Array(checked))
        store.addStorm(storm)
        withAnimation { savedFlash = true }
        checked = []; observations = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { savedFlash = false }
    }

    private func schedulePostStorm() {
        NotificationService.shared.requestAuthorization { granted in
            let r = Reminder(kind: .postStorm,
                             title: ReminderKind.postStorm.label,
                             body: "Re-check after the \(stormType.lowercased()) — confirm nothing has worsened.",
                             fireDate: Date().addingTimeInterval(3 * 86400),
                             repeats: false, isEnabled: granted)
            store.setReminder(r)
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }
}
