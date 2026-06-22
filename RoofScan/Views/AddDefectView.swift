//
//  AddDefectView.swift
//  RoofScan
//
//  03 — Add Defect Marker. Pins a defect to a point on a chosen slope,
//  with type, size, 1–5 severity, photo (point-pinned) and a note.
//

import SwiftUI

struct AddDefectView: View {
    @EnvironmentObject private var store: RoofStore
    @Environment(\.presentationMode) private var presentationMode

    var preselectedSlopeID: UUID?

    @State private var slopeID: UUID?
    @State private var type: DefectType = .crack
    @State private var size = ""
    @State private var severity = 3
    @State private var note = ""
    @State private var photoFilename: String?
    @State private var x: Double = 0.5
    @State private var y: Double = 0.45
    @State private var loaded = false

    private var canSave: Bool { slopeID != nil }

    var body: some View {
        SheetScaffold(title: "Add Marker", saveLabel: "Add", canSave: canSave,
                      onCancel: dismiss, onSave: save) {

            if store.project.slopes.isEmpty {
                InfoBanner(text: "Add a slope first — markers are pinned to a slope.",
                           icon: "exclamationmark.triangle.fill")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Slope").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(store.project.slopes) { s in
                            Chip(label: s.name, selected: slopeID == s.id) { slopeID = s.id }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Defect type").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(DefectType.allCases) { t in
                            Chip(label: t.label, icon: t.icon, selected: type == t,
                                 tint: store.project.covering.commonDefects.contains(t) ? Theme.amber : Theme.primary) {
                                type = t
                            }
                        }
                    }
                    if store.project.covering.commonDefects.contains(type) {
                        Text("Common on \(store.project.covering.label).")
                            .font(.system(size: 11)).foregroundColor(Theme.amber)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pin point on slope").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    SlopePositionPad(x: $x, y: $y)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Severity").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    SeverityPicker(severity: $severity)
                }

                LabeledField(label: "Size / extent", text: $size, placeholder: "e.g. 30 cm crack")
                PhotoPickerField(filename: $photoFilename)
                LabeledNote(label: "Note", text: $note)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            slopeID = preselectedSlopeID ?? store.project.slopes.first?.id
        }
    }

    private func save() {
        guard let sid = slopeID else { return }
        let d = Defect(slopeID: sid, type: type, sizeDescription: size,
                       severity: severity, photoFilename: photoFilename,
                       note: note, x: x, y: y)
        store.addDefect(d)
        if let f = photoFilename {
            store.addPhoto(PhotoEvidence(filename: f, caption: "\(type.label) on \(store.slopeName(sid))",
                                         slopeID: sid, defectID: d.id))
        }
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }
}

// MARK: - Position pad

struct SlopePositionPad: View {
    @Binding var x: Double
    @Binding var y: Double

    var body: some View {
        GeometryReader { g in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.cardHover, Theme.bgDepth], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
                EdgeLine(a: CGPoint(x: 0, y: 6), b: CGPoint(x: g.size.width, y: 6))
                    .stroke(Theme.ridge, lineWidth: 3)
                VStack {
                    Text("Ridge (up-slope)").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.ridge)
                    Spacer()
                    Text("Eave (down-slope)").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.valley)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                PulsingMarker(color: Theme.signalOrange, size: 26, pulse: false)
                    .position(x: CGFloat(x) * g.size.width, y: CGFloat(y) * g.size.height)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        x = max(0.04, min(0.96, Double(v.location.x / g.size.width)))
                        y = max(0.06, min(0.94, Double(v.location.y / g.size.height)))
                    }
            )
        }
        .frame(height: 160)
    }
}
