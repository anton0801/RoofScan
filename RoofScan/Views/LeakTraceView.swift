//
//  LeakTraceView.swift
//  RoofScan
//
//  04 — Leak Trace (signature feature). Mark where the interior stain is and
//  which slope is above it; the engine builds an up-slope inspection corridor,
//  because water always enters higher than the visible leak.
//

import SwiftUI

struct LeakTraceView: View {
    @EnvironmentObject private var store: RoofStore
    @StateObject private var vm = LeakTraceViewModel()
    @State private var savedFlash = false

    var body: some View {
        ScreenScaffold(title: "Leak Trace", subtitle: "Follow the water back up-slope") {

            InfoBanner(text: "Water enters above the stain and runs down. Inspect the suspects in order, starting highest.",
                       icon: "drop.fill", tint: Theme.ridge)

            if store.project.slopes.isEmpty {
                CardView { EmptyStateView(icon: "drop.degreesign", title: "No slopes",
                                          message: "Add slopes first so we can map the corridor above the leak.") }
            } else {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledField(label: "Interior wet spot", text: $vm.interiorSpot,
                                     placeholder: "e.g. Kitchen ceiling, NE corner")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Slope above it").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(store.project.slopes) { s in
                                    Chip(label: s.name, selected: vm.selectedSlopeID == s.id) {
                                        vm.selectedSlopeID = s.id
                                    }
                                }
                            }
                        }
                        PrimaryButton(title: "Trace corridor", icon: "scope", enabled: vm.canRun) {
                            rsHideKeyboardGlobal()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                vm.run(project: store.project)
                            }
                        }
                    }
                }

                if vm.didRun && !vm.suspects.isEmpty {
                    resultsSection
                }
            }

            if !store.project.leaks.isEmpty {
                SectionHeader(title: "Saved traces", icon: "clock.arrow.circlepath")
                ForEach(store.project.leaks) { trace in
                    savedTraceRow(trace)
                }
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardView(tint: Theme.ridge.opacity(0.12)) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.up.forward").foregroundColor(Theme.ridge)
                    Text(vm.corridor).font(.rsBody()).foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SectionHeader(title: "Suspects to check", subtitle: "Highest priority first", icon: "list.number")

            ForEach(vm.suspects) { suspect in
                SuspectCard(suspect: suspect)
            }

            PrimaryButton(title: savedFlash ? "Saved ✓" : "Save trace", icon: "tray.and.arrow.down.fill") {
                vm.save(to: store)
                withAnimation { savedFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { savedFlash = false }
            }
        }
    }

    private func savedTraceRow(_ trace: LeakTrace) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trace.interiorSpot).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button {
                        store.deleteLeak(trace)
                    } label: {
                        Image(systemName: "trash").foregroundColor(Theme.critical)
                    }
                }
                Text("Above \(store.slopeName(trace.slopeID)) · top suspect: \(trace.suspects.first?.node.label ?? "—")")
                    .font(.rsCaption()).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func rsHideKeyboardGlobal() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct SuspectCard: View {
    let suspect: SuspectNode

    var body: some View {
        let tint = rankColor(suspect.rank)
        return CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(tint.opacity(0.2)).frame(width: 40, height: 40)
                        Text("\(suspect.rank)").font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: suspect.node.icon).foregroundColor(tint).font(.system(size: 13))
                            Text(suspect.node.label).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                        }
                        Text("Likelihood \(Int(suspect.likelihood * 100))%")
                            .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                ProgressBar(fraction: suspect.likelihood, tint: tint)
                Text(suspect.rationale).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.critical
        case 2: return Theme.signalOrange
        case 3: return Theme.amber
        default: return Theme.primary
        }
    }
}
