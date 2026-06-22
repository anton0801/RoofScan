//
//  FlashingJointsView.swift
//  RoofScan
//
//  05 — Flashing & Joints. Penetrations/abutments are the most common leak
//  source; track condition per joint.
//

import SwiftUI

struct FlashingJointsView: View {
    @EnvironmentObject private var store: RoofStore
    @State private var showAdd = false
    @State private var editing: FlashingJoint?

    var body: some View {
        ScreenScaffold(title: "Flashing & Joints", subtitle: "The usual leak suspects") {
            InfoBanner(text: "Most leaks start at a flashing. Log each penetration and keep its condition current.",
                       icon: "building.2.fill", tint: Theme.amber)

            if store.project.flashings.isEmpty {
                CardView { EmptyStateView(icon: "building.2", title: "No joints logged",
                                          message: "Add chimneys, vents, walls and skylights to track.",
                                          actionTitle: "Add joint") { showAdd = true } }
            } else {
                ForEach(store.project.flashings) { f in
                    Button { editing = f } label: { row(f) }.buttonStyle(PressableStyle())
                }
                summary
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { FlashingFormView() }
        .sheet(item: $editing) { f in FlashingFormView(editing: f) }
    }

    private func row(_ f: FlashingJoint) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(SeverityPalette.condition(f.condition).opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: f.location.icon).foregroundColor(SeverityPalette.condition(f.condition))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(f.label.isEmpty ? f.location.label : f.label)
                        .font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                    Text(f.note.isEmpty ? f.location.label : f.note)
                        .font(.rsCaption()).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                ConditionBadge(condition: f.condition)
            }
        }
    }

    private var summary: some View {
        let failed = store.project.flashings.filter { $0.condition == .failed }.count
        return CardView(tint: failed > 0 ? Theme.critical.opacity(0.12) : Theme.card) {
            KeyValueRow(key: "Joints tracked", value: "\(store.project.flashings.count)")
            KeyValueRow(key: "Failed / leaking", value: "\(failed)",
                        valueColor: failed > 0 ? Theme.critical : Theme.ok)
        }
    }
}

// MARK: - Add / edit form

struct FlashingFormView: View {
    @EnvironmentObject private var store: RoofStore
    @Environment(\.presentationMode) private var presentationMode
    var editing: FlashingJoint?

    @State private var location: FlashingLocation = .chimney
    @State private var label = ""
    @State private var condition: ConditionState = .good
    @State private var note = ""
    @State private var photoFilename: String?
    @State private var loaded = false

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Joint" : "Edit Joint",
                      onCancel: dismiss, onSave: save) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Location").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(FlashingLocation.allCases) { l in
                        Chip(label: l.label, icon: l.icon, selected: location == l) { location = l }
                    }
                }
            }
            LabeledField(label: "Label (optional)", text: $label, placeholder: "e.g. Main chimney")
            VStack(alignment: .leading, spacing: 8) {
                Text("Condition").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(ConditionState.allCases) { c in
                        Chip(label: c.label, selected: condition == c,
                             tint: SeverityPalette.condition(c)) { condition = c }
                    }
                }
            }
            PhotoPickerField(filename: $photoFilename)
            LabeledNote(label: "Note", text: $note)

            if editing != nil {
                DangerButton(title: "Delete joint", icon: "trash.fill") {
                    if let f = editing { store.deleteFlashing(f) }
                    dismiss()
                }
            }
        }
        .onAppear {
            guard !loaded else { return }; loaded = true
            if let f = editing {
                location = f.location; label = f.label; condition = f.condition
                note = f.note; photoFilename = f.photoFilename
            }
        }
    }

    private func save() {
        if var f = editing {
            f.location = location; f.label = label; f.condition = condition
            f.note = note; f.photoFilename = photoFilename; f.lastChecked = Date()
            store.updateFlashing(f)
        } else {
            store.addFlashing(FlashingJoint(location: location, label: label,
                                            condition: condition, note: note,
                                            photoFilename: photoFilename))
        }
        dismiss()
    }
    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}
