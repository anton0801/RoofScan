//
//  AddSlopeView.swift
//  RoofScan
//
//  02 — Add Slope. Name, side, pitch, dimensions and perimeter nodes.
//  The app derives the drainage direction from the slope's facing.
//

import SwiftUI

struct AddSlopeView: View {
    @EnvironmentObject private var store: RoofStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode

    /// When editing an existing slope.
    var editing: Slope? = nil

    @State private var name = ""
    @State private var orientation: Orientation = .south
    @State private var pitch: Double = 30
    @State private var lengthText = ""
    @State private var widthText = ""
    @State private var nodes: Set<NodeType> = []
    @State private var loaded = false

    private var lengthM: Double? { parsed(lengthText).map { $0 / settings.unitSystem.lengthFactor } }
    private var widthM: Double? { parsed(widthText).map { $0 / settings.unitSystem.lengthFactor } }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (lengthM ?? 0) > 0 && (widthM ?? 0) > 0
    }

    var body: some View {
        SheetScaffold(title: editing == nil ? "Add Slope" : "Edit Slope",
                      saveLabel: "Save", canSave: canSave,
                      onCancel: dismiss, onSave: save) {

            LabeledField(label: "Slope name", text: $name, placeholder: "e.g. South main")

            VStack(alignment: .leading, spacing: 8) {
                Text("Side it faces").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(Orientation.allCases) { o in
                        Chip(label: o.label, selected: orientation == o) { orientation = o }
                    }
                }
            }

            CardView {
                LabeledSlider(label: "Pitch", value: $pitch, range: 0...60, step: 1,
                              unit: "°", format: "%.0f")
                KeyValueRow(key: "As percent", value: String(format: "%.0f%%", tan(pitch * .pi / 180) * 100))
                KeyValueRow(key: "Water drains toward", value: orientation.label, valueColor: Theme.ridge)
            }

            HStack(spacing: 12) {
                LabeledField(label: "Length (\(settings.unitSystem.lengthUnit))", text: $lengthText,
                             placeholder: "0", keyboard: .decimalPad)
                LabeledField(label: "Width (\(settings.unitSystem.lengthUnit))", text: $widthText,
                             placeholder: "0", keyboard: .decimalPad)
            }
            if let l = lengthM, let w = widthM, l > 0, w > 0 {
                let area = l * w / cos(min(max(pitch, 0), 75) * .pi / 180)
                KeyValueRow(key: "Sloped area", value: settings.area(area), valueColor: Theme.amber)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Perimeter & feature nodes").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(NodeType.allCases) { n in
                        Chip(label: n.label, icon: n.icon, selected: nodes.contains(n)) {
                            if nodes.contains(n) { nodes.remove(n) } else { nodes.insert(n) }
                        }
                    }
                }
                Text("Nodes feed the leak-tracing engine.")
                    .font(.system(size: 11)).foregroundColor(Theme.textDisabled)
            }
        }
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let s = editing {
            name = s.name
            orientation = s.orientation
            pitch = s.pitchDegrees
            lengthText = trimmed(s.length * settings.unitSystem.lengthFactor)
            widthText = trimmed(s.width * settings.unitSystem.lengthFactor)
            nodes = Set(s.nodeTypes)
        } else {
            nodes = Set(store.project.roofType.typicalNodes)
        }
    }

    private func save() {
        guard let l = lengthM, let w = widthM, canSave else { return }
        if var s = editing {
            s.name = name; s.orientation = orientation; s.pitchDegrees = pitch
            s.length = l; s.width = w; s.nodeTypes = Array(nodes)
            store.updateSlope(s)
        } else {
            let s = Slope(name: name.trimmingCharacters(in: .whitespaces),
                          orientation: orientation, pitchDegrees: pitch,
                          length: l, width: w, nodeTypes: Array(nodes))
            store.addSlope(s)
        }
        dismiss()
    }

    private func dismiss() { presentationMode.wrappedValue.dismiss() }

    private func parsed(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }
    private func trimmed(_ v: Double) -> String {
        String(format: v == v.rounded() ? "%.0f" : "%.1f", v)
    }
}
