//
//  GutterDrainageView.swift
//  RoofScan
//
//  06 — Gutter & Drainage. Where water fails to leave the roof and hits the facade.
//

import SwiftUI

struct GutterDrainageView: View {
    @EnvironmentObject private var store: RoofStore
    @State private var showAdd = false
    @State private var editing: DrainageSegment?

    var body: some View {
        ScreenScaffold(title: "Gutter & Drainage", subtitle: "Keep water leaving cleanly") {
            InfoBanner(text: "Blocked or sagging runs back water onto the roof and down the facade.",
                       icon: "drop.fill", tint: Theme.ridge)

            if store.project.drainage.isEmpty {
                CardView { EmptyStateView(icon: "drop", title: "No runs logged",
                                          message: "Add gutter runs and downpipes to track blockages and overflow.",
                                          actionTitle: "Add run") { showAdd = true } }
            } else {
                ForEach(store.project.drainage) { g in
                    Button { editing = g } label: { row(g) }.buttonStyle(PressableStyle())
                }
                let overflow = store.project.drainage.filter { $0.overflowsToFacade }.count
                CardView(tint: overflow > 0 ? Theme.critical.opacity(0.12) : Theme.card) {
                    KeyValueRow(key: "Runs tracked", value: "\(store.project.drainage.count)")
                    KeyValueRow(key: "Hitting facade", value: "\(overflow)",
                                valueColor: overflow > 0 ? Theme.critical : Theme.ok)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { GutterFormView() }
        .sheet(item: $editing) { g in GutterFormView(editing: g) }
    }

    private func row(_ g: DrainageSegment) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint(g).opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: g.issue?.icon ?? "checkmark").foregroundColor(tint(g))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(g.name).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                    Text(g.issue?.label ?? "No issue").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if g.issue != nil { SeverityBadge(severity: g.severity) }
                if g.overflowsToFacade {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.critical)
                }
            }
        }
    }

    private func tint(_ g: DrainageSegment) -> Color {
        g.issue == nil ? Theme.ok : SeverityPalette.color(severity: g.severity)
    }
}

struct GutterFormView: View {
    @EnvironmentObject private var store: RoofStore
    @Environment(\.presentationMode) private var presentationMode
    var editing: DrainageSegment?

    @State private var name = ""
    @State private var issue: GutterIssue?
    @State private var severity = 2
    @State private var overflow = false
    @State private var note = ""
    @State private var loaded = false

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Run" : "Edit Run", canSave: canSave,
                      onCancel: dismiss, onSave: save) {
            LabeledField(label: "Run / downpipe name", text: $name, placeholder: "e.g. North gutter")
            VStack(alignment: .leading, spacing: 8) {
                Text("Issue").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    Chip(label: "None", selected: issue == nil, tint: Theme.ok) { issue = nil }
                    ForEach(GutterIssue.allCases) { i in
                        Chip(label: i.label, icon: i.icon, selected: issue == i) { issue = i }
                    }
                }
            }
            if issue != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Severity").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    SeverityPicker(severity: $severity)
                }
            }
            CardView { ToggleRow(title: "Overflows onto facade", icon: "exclamationmark.triangle.fill", isOn: $overflow) }
            LabeledNote(label: "Note", text: $note)

            if editing != nil {
                DangerButton(title: "Delete run", icon: "trash.fill") {
                    if let g = editing { store.deleteDrainage(g) }
                    dismiss()
                }
            }
        }
        .onAppear {
            guard !loaded else { return }; loaded = true
            if let g = editing {
                name = g.name; issue = g.issue; severity = max(1, g.severity)
                overflow = g.overflowsToFacade; note = g.note
            }
        }
    }

    private func save() {
        let sev = issue == nil ? 0 : severity
        if var g = editing {
            g.name = name; g.issue = issue; g.severity = sev; g.overflowsToFacade = overflow; g.note = note
            store.updateDrainage(g)
        } else {
            store.addDrainage(DrainageSegment(name: name, issue: issue, severity: sev,
                                              note: note, overflowsToFacade: overflow))
        }
        dismiss()
    }
    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
