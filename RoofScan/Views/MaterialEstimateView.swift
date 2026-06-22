//
//  MaterialEstimateView.swift
//  RoofScan
//
//  09 — Material Estimate. Take-off for repairing selected slope area by covering.
//

import SwiftUI

struct MaterialEstimateView: View {
    @EnvironmentObject private var store: RoofStore
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm = MaterialEstimateViewModel()
    @State private var loaded = false

    var body: some View {
        ScreenScaffold(title: "Material Estimate", subtitle: store.project.covering.label + " take-off") {
            if store.project.slopes.isEmpty {
                CardView { EmptyStateView(icon: "shippingbox", title: "No slopes",
                                          message: "Add slopes to estimate repair materials.") }
            } else {
                CardView {
                    SectionHeader(title: "Area to repair", icon: "square.dashed")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(store.project.slopes) { s in
                            Chip(label: "\(s.name) · \(settings.area(s.area))",
                                 selected: vm.selectedSlopeIDs.contains(s.id)) { vm.toggle(s.id) }
                        }
                    }
                    HStack {
                        Button("Select all") { vm.selectAll(store.project) }
                            .font(.rsCaption()).foregroundColor(Theme.primary)
                        Spacer()
                        Text("Total: \(settings.area(vm.totalArea(store.project)))")
                            .font(.rsBodyBold()).foregroundColor(Theme.amber)
                    }
                }

                CardView {
                    LabeledSlider(label: "Waste / offcuts", value: $vm.wastePercent,
                                  range: 0...25, step: 1, unit: "%", format: "%.0f", tint: Theme.amber)
                }

                PrimaryButton(title: "Calculate materials", icon: "function",
                              enabled: !vm.selectedSlopeIDs.isEmpty) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.compute(store.project) }
                }

                if let bill = vm.bill {
                    CardView {
                        SectionHeader(title: "Bill of materials",
                                      subtitle: "for \(settings.area(bill.totalArea)) of \(store.project.covering.label)",
                                      icon: "list.bullet.rectangle.fill")
                        ForEach(bill.lines) { line in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.name).font(.rsBody()).foregroundColor(Theme.textPrimary)
                                    Text(line.note).font(.system(size: 11)).foregroundColor(Theme.textDisabled)
                                }
                                Spacer()
                                Text("\(Int(line.quantity)) \(line.unit)")
                                    .font(.rsBodyBold()).foregroundColor(Theme.amber)
                            }
                            .padding(.vertical, 5)
                            if line.id != bill.lines.last?.id { Divider().background(Theme.divider) }
                        }
                    }
                    InfoBanner(text: "Quantities include \(Int(vm.wastePercent))% waste. Verify against supplier pack sizes.")
                }
            }
        }
        .onAppear {
            guard !loaded else { return }; loaded = true
            vm.selectAll(store.project)
        }
    }
}
