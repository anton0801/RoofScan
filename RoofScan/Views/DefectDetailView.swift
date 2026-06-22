//
//  DefectDetailView.swift
//  RoofScan
//
//  Tap a marker → edit its severity, status, size, note, photo, or delete it.
//

import SwiftUI

struct DefectDetailView: View {
    @EnvironmentObject private var store: RoofStore
    @Environment(\.presentationMode) private var presentationMode

    let defectID: UUID

    @State private var draft: Defect?
    @State private var original: Defect?
    @State private var showDelete = false

    var body: some View {
        Group {
            if let d = draft {
                editor(for: d)
            } else {
                SheetScaffold(title: "Defect", canSave: false, onCancel: dismiss, onSave: {}) {
                    EmptyStateView(icon: "questionmark.circle", title: "Not found",
                                   message: "This marker no longer exists.")
                }
            }
        }
        .onAppear {
            if draft == nil {
                let found = store.project.defects.first { $0.id == defectID }
                draft = found
                original = found
            }
        }
    }

    @ViewBuilder
    private func editor(for d: Defect) -> some View {
        SheetScaffold(title: d.type.label, saveLabel: "Save", canSave: true,
                      onCancel: dismiss, onSave: save) {

            CardView {
                KeyValueRow(key: "Slope", value: store.slopeName(d.slopeID), valueColor: Theme.ridge)
                KeyValueRow(key: "Recorded", value: dateString(d.createdDate))
            }

            if d.photoFilename != nil {
                HStack {
                    PhotoThumb(filename: d.photoFilename, size: 120, corner: 14)
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Status").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(DefectStatus.allCases) { s in
                        Chip(label: s.label, selected: draft?.status == s,
                             tint: SeverityPalette.color(for: s)) {
                            draft?.status = s
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Severity").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                SeverityPicker(severity: Binding(
                    get: { draft?.severity ?? 3 },
                    set: { draft?.severity = $0 }))
            }

            LabeledField(label: "Size / extent",
                         text: Binding(get: { draft?.sizeDescription ?? "" },
                                       set: { draft?.sizeDescription = $0 }),
                         placeholder: "e.g. 30 cm")

            PhotoPickerField(filename: Binding(get: { draft?.photoFilename },
                                               set: { draft?.photoFilename = $0 }))

            LabeledNote(label: "Note",
                        text: Binding(get: { draft?.note ?? "" },
                                      set: { draft?.note = $0 }))

            VStack(spacing: 10) {
                if draft?.status != .repaired {
                    PrimaryButton(title: "Mark repaired", icon: "checkmark.seal.fill") {
                        draft?.status = .repaired
                    }
                }
                DangerButton(title: "Delete marker", icon: "trash.fill") { showDelete = true }
            }
            .padding(.top, 4)
        }
        .alert(isPresented: $showDelete) {
            Alert(title: Text("Delete marker?"),
                  message: Text("This removes the defect and its photo."),
                  primaryButton: .destructive(Text("Delete")) { deleteDefect() },
                  secondaryButton: .cancel())
        }
    }

    private func save() {
        guard let d = draft else { return }
        store.updateDefect(d)
        if let o = original, o.status != .repaired, d.status == .repaired {
            store.setDefectStatus(d.id, .repaired)
        }
        dismiss()
    }

    private func deleteDefect() {
        if let d = draft { store.deleteDefect(d) }
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
