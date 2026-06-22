//
//  ReportsView.swift
//  RoofScan
//
//  15 — Reports. The roof defect schedule + remaining life + repair totals,
//  exportable as a PDF. Also the hub for History, Timeline and Photos.
//

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var store: RoofStore
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm = ReportsViewModel()

    var body: some View {
        ScreenScaffold(title: "Reports", subtitle: "Defect schedule & export") {

            // Summary
            CardView {
                HStack(spacing: 16) {
                    HealthRing(percent: store.health.overall, size: 92, lineWidth: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        StatRow(icon: "exclamationmark.triangle.fill", label: "Active defects",
                                value: "\(store.project.activeDefectCount)", tint: Theme.signalOrange)
                        StatRow(icon: "calendar.badge.clock", label: "Remaining life",
                                value: String(format: "%.0f yr", store.serviceLife.remainingYears),
                                tint: store.serviceLife.tier.color)
                        StatRow(icon: "square.3.layers.3d", label: "Slopes",
                                value: "\(store.project.slopes.count)", tint: Theme.ridge)
                    }
                    Spacer(minLength: 0)
                }
            }

            // Export
            CardView {
                SectionHeader(title: "Export PDF", icon: "doc.richtext.fill")
                ToggleRow(title: "Include photos", icon: "photo.fill", isOn: $vm.includePhotos)
                PrimaryButton(title: vm.generating ? "Generating…" : "Generate PDF report",
                              icon: "square.and.arrow.up", enabled: !vm.generating) {
                    vm.generate(project: store.project, settings: settings)
                }
            }

            // Defect schedule preview
            CardView {
                SectionHeader(title: "Defect schedule", subtitle: "by slope & severity", icon: "list.bullet.rectangle.portrait.fill")
                if store.project.defects.isEmpty {
                    Text("No defects recorded.").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                } else {
                    ForEach(store.project.slopes) { s in
                        let ds = store.project.defects(on: s.id)
                        if !ds.isEmpty {
                            Text(s.name).font(.rsBodyBold()).foregroundColor(Theme.ridge).padding(.top, 4)
                            ForEach(ds.sorted { $0.severity > $1.severity }) { d in
                                HStack {
                                    Text("• \(d.type.label)").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    SeverityBadge(severity: d.severity)
                                }
                            }
                        }
                    }
                }
            }

            // Sub-reports
            SectionHeader(title: "More", icon: "tray.full.fill")
            NavigationLink(destination: HistoryView()) {
                NavRow(icon: "clock.arrow.circlepath", title: "History", subtitle: "Everything that changed", tint: Theme.primary)
            }
            NavigationLink(destination: TimelineCompareView()) {
                NavRow(icon: "chart.xyaxis.line", title: "Timeline Compare", subtitle: "How health trends", tint: Theme.amber)
            }
            NavigationLink(destination: PhotoEvidenceView()) {
                NavRow(icon: "photo.on.rectangle.angled", title: "Photo Evidence", subtitle: "\(store.project.photos.count) photos", tint: Theme.ridge)
            }

            InfoBanner(text: "Reports are an estimate to support — not replace — an on-site roofer's assessment.")
        }
        .sheet(isPresented: $vm.isSharing) {
            if let url = vm.generatedURL { ShareSheet(items: [url]) }
        }
    }
}
