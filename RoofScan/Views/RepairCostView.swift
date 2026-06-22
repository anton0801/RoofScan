//
//  RepairCostView.swift
//  RoofScan
//
//  10 — Repair Cost. Material + labor per defect at the user's hourly rate,
//  split into do-now and can-defer.
//

import SwiftUI

struct RepairCostView: View {
    @EnvironmentObject private var store: RoofStore
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm = RepairCostViewModel()

    var body: some View {
        ScreenScaffold(title: "Repair Cost", subtitle: "Material + labor by defect") {
            CardView {
                LabeledSlider(label: "Your labor rate", value: $settings.hourlyRate,
                              range: 10...200, step: 5, unit: "\(settings.currency)/hr", format: "%.0f")
                HStack {
                    Text("Currency").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(settings.currency)").font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                }
            }

            PrimaryButton(title: "Estimate cost", icon: "function") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    vm.compute(project: store.project, rate: settings.hourlyRate, currency: settings.currency)
                }
                store.noteEstimateRun("Repair cost estimate")
            }

            if store.project.defects.filter({ $0.status != .repaired }).isEmpty {
                CardView { EmptyStateView(icon: "checkmark.seal.fill", title: "Nothing to repair",
                                          message: "No open defects to price right now.") }
            }

            if let est = vm.estimate {
                CardView {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Do now").font(.rsCaption()).foregroundColor(Theme.critical)
                            Text(settings.money(est.doNowTotal))
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Full total").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                            Text(settings.money(est.total))
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.amber)
                        }
                    }
                    Divider().background(Theme.divider)
                    KeyValueRow(key: "Materials", value: settings.money(est.materialTotal))
                    KeyValueRow(key: "Labor", value: settings.money(est.laborTotal))
                }

                if !est.doNow.isEmpty {
                    SectionHeader(title: "Do now", subtitle: "Leak-risk or severe", icon: "exclamationmark.octagon.fill")
                    ForEach(est.doNow) { line in lineCard(line) }
                }
                if !est.deferred.isEmpty {
                    SectionHeader(title: "Can defer", icon: "clock.fill")
                    ForEach(est.deferred) { line in lineCard(line) }
                }
                InfoBanner(text: "Labor uses your \(settings.money(settings.hourlyRate))/hr rate × estimated hours. Material costs are indicative.")
            }
        }
    }

    private func lineCard(_ line: RepairLine) -> some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(line.label).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                    Text("\(settings.money(line.materialCost)) mat · \(String(format: "%.1f", line.laborHours)) h labor")
                        .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text(settings.money(line.total))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(line.doNow ? Theme.critical : Theme.amber)
            }
        }
    }
}
