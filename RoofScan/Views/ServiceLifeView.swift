//
//  ServiceLifeView.swift
//  RoofScan
//
//  07 — Service-Life Estimate. Covering + age + defects + climate → years left
//  and a repair / replace recommendation, with what's dragging life down.
//

import SwiftUI

struct ServiceLifeView: View {
    @EnvironmentObject private var store: RoofStore

    var body: some View {
        let life = store.serviceLife
        let health = store.health

        ScreenScaffold(title: "Service Life", subtitle: "\(store.project.covering.label) · \(store.project.ageYears) yr old") {

            CardView {
                HStack(spacing: 18) {
                    HealthRing(percent: health.overall, size: 100, lineWidth: 11)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "%.1f", life.remainingYears))
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(life.tier.color)
                        Text("years remaining").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        TierBadge(tier: life.tier)
                    }
                    Spacer(minLength: 0)
                }
            }

            // Life consumed bar
            CardView {
                SectionHeader(title: "Life consumed", icon: "hourglass")
                ProgressBar(fraction: 1 - life.lifeFraction, tint: life.tier.color, height: 14)
                HStack {
                    Text("0").font(.rsCaption()).foregroundColor(Theme.textDisabled)
                    Spacer()
                    Text("\(life.baselineLife) yr baseline").font(.rsCaption()).foregroundColor(Theme.textDisabled)
                }
            }

            // Breakdown
            CardView {
                SectionHeader(title: "How we got here", icon: "function")
                KeyValueRow(key: "Baseline life (\(store.project.covering.label))", value: "+\(life.baselineLife) yr")
                KeyValueRow(key: "Age", value: "−\(store.project.ageYears) yr", valueColor: Theme.amber)
                KeyValueRow(key: "Defect penalty", value: String(format: "−%.1f yr", life.defectPenalty),
                            valueColor: Theme.signalOrange)
                KeyValueRow(key: "Climate penalty", value: String(format: "−%.1f yr", life.climatePenalty),
                            valueColor: Theme.signalOrange)
                Divider().background(Theme.divider)
                KeyValueRow(key: "Remaining", value: String(format: "%.1f yr", life.remainingYears),
                            valueColor: life.tier.color)
            }

            // Factors dragging life down
            if !life.topFactors.isEmpty {
                CardView {
                    SectionHeader(title: "What drags it down", icon: "arrow.down.right")
                    ForEach(life.topFactors) { f in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(f.label).font(.rsBody()).foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text(String(format: "−%.1f yr", f.yearsLost))
                                    .font(.rsBodyBold()).foregroundColor(Theme.signalOrange)
                            }
                            ProgressBar(fraction: min(1, f.yearsLost / Double(max(1, life.baselineLife))),
                                        tint: Theme.signalOrange, height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            CardView(tint: life.tier.color.opacity(0.12)) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: life.tier.icon).foregroundColor(life.tier.color)
                    Text(recommendation(life)).font(.rsBody()).foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            InfoBanner(text: "Estimate only — does not replace an on-site inspection by a qualified roofer.")
        }
        .onAppear { store.noteEstimateRun("Service-life: \(String(format: "%.1f", store.serviceLife.remainingYears)) yr remaining") }
    }

    private func recommendation(_ life: ServiceLifeResult) -> String {
        switch life.tier {
        case .monitor:
            return "Plenty of life left. Keep up seasonal inspections and fix small defects early."
        case .repair:
            return "Worth repairing now. Address leak-risk defects and flashings to protect the remaining life."
        case .planReplacement:
            return "Start budgeting for replacement. Repairs will buy time but the covering is well into its decline."
        case .replaceNow:
            return "Replacement is due. Active leaks and low remaining life mean repairs are unlikely to pay off."
        }
    }
}
