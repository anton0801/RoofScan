//
//  RemindersView.swift
//  RoofScan
//
//  18 — Reminders. Real UNUserNotificationCenter reminders: seasonal inspections,
//  post-storm, gutter cleaning and critical-defect re-checks.
//

import SwiftUI
import UserNotifications

struct RemindersView: View {
    @EnvironmentObject private var store: RoofStore

    @State private var authorized = false
    @State private var newKind: ReminderKind = .seasonalSpring
    @State private var newDate = Date().addingTimeInterval(86400)
    @State private var newRepeats = true

    var body: some View {
        ScreenScaffold(title: "Reminders", subtitle: "Never miss a seasonal check") {

            if !authorized {
                CardView(tint: Theme.amber.opacity(0.12)) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.slash.fill").foregroundColor(Theme.amber)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are off").font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                            Text("Enable them so reminders can actually alert you.")
                                .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                            SecondaryButton(title: "Enable notifications", icon: "bell.fill") { requestAuth() }
                        }
                    }
                }
            }

            // Existing reminders
            if store.project.reminders.isEmpty {
                CardView { EmptyStateView(icon: "bell", title: "No reminders",
                                          message: "Add a seasonal or post-storm reminder below.") }
            } else {
                ForEach(store.project.reminders) { r in
                    reminderRow(r)
                }
            }

            // Quick: critical re-check
            if let worst = worstDefect {
                SecondaryButton(title: "Re-check worst defect in 7 days", icon: "exclamationmark.triangle.fill") {
                    let r = Reminder(kind: .criticalRecheck,
                                     title: "Re-check \(worst.type.label)",
                                     body: "A severity-\(worst.severity) defect on \(store.slopeName(worst.slopeID)) is due for a look.",
                                     fireDate: Date().addingTimeInterval(7 * 86400),
                                     repeats: false, isEnabled: authorized, relatedDefectID: worst.id)
                    store.setReminder(r)
                }
            }

            // Add custom
            CardView {
                SectionHeader(title: "Add reminder", icon: "plus.circle.fill")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ReminderKind.allCases) { k in
                        Chip(label: k.label, icon: k.icon, selected: newKind == k) { newKind = k }
                    }
                }
                DatePicker("Date", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .accentColor(Theme.primary)
                    .foregroundColor(Theme.textPrimary)
                ToggleRow(title: "Repeat yearly", icon: "repeat", isOn: $newRepeats)
                PrimaryButton(title: "Add reminder", icon: "bell.badge.fill") { addReminder() }
            }

            SecondaryButton(title: "Send test alert (10s)", icon: "paperplane.fill") {
                NotificationService.shared.requestAuthorization { granted in
                    authorized = granted
                    if granted {
                        NotificationService.shared.scheduleTest(title: "Roof Scan",
                            body: "Test reminder — your notifications work.",
                            after: 10, id: "test.\(UUID().uuidString)")
                    }
                }
            }

            InfoBanner(text: "Reminders are local to this device. Seasonal cadence adapts to your climate load.")
        }
        .onAppear { refreshAuth() }
    }

    private func reminderRow(_ r: Reminder) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.primary.opacity(0.16)).frame(width: 40, height: 40)
                    Image(systemName: r.kind.icon).foregroundColor(Theme.highlight)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.title).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                    Text("\(dateString(r.fireDate))\(r.repeats ? " · yearly" : "")")
                        .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { r.isEnabled },
                    set: { on in
                        if on && !authorized { requestAuth() }
                        store.toggleReminder(r, on: on)
                    }))
                    .labelsHidden().toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                Button { store.deleteReminder(r) } label: {
                    Image(systemName: "trash").foregroundColor(Theme.critical)
                }
            }
        }
    }

    private var worstDefect: Defect? {
        store.project.defects.filter { $0.status != .repaired }.max { $0.severity < $1.severity }
    }

    private func addReminder() {
        let r = Reminder(kind: newKind, title: newKind.label, body: newKind.defaultBody,
                         fireDate: newDate, repeats: newRepeats, isEnabled: true)
        if !authorized { requestAuth() }
        store.setReminder(r)
    }

    private func requestAuth() {
        NotificationService.shared.requestAuthorization { granted in authorized = granted }
    }
    private func refreshAuth() {
        NotificationService.shared.authorizationStatus { status in
            authorized = (status == .authorized || status == .provisional || status == .ephemeral)
        }
    }
    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
