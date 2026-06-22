//
//  HistoryView.swift
//  RoofScan
//
//  16 — History. The activity feed: markers added, defects grown, repairs,
//  storms, inspections, reminders.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: RoofStore
    @State private var filter: HistoryEventType?

    private var events: [HistoryEvent] {
        guard let f = filter else { return store.project.history }
        return store.project.history.filter { $0.type == f }
    }

    var body: some View {
        ScreenScaffold(title: "History", subtitle: "\(store.project.history.count) events") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(label: "All", selected: filter == nil) { filter = nil }
                    ForEach(HistoryEventType.allCases) { t in
                        Chip(label: t.label, icon: t.icon, selected: filter == t, tint: t.color) {
                            filter = (filter == t) ? nil : t
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            if events.isEmpty {
                CardView { EmptyStateView(icon: "clock.arrow.circlepath", title: "Nothing yet",
                                          message: "Actions you take are logged here over time.") }
            } else {
                ForEach(events) { ev in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().fill(ev.type.color.opacity(0.18)).frame(width: 38, height: 38)
                            Image(systemName: ev.type.icon).foregroundColor(ev.type.color).font(.system(size: 15))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ev.summary).font(.rsBody()).foregroundColor(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(dateString(ev.date)).font(.rsCaption()).foregroundColor(Theme.textDisabled)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
