//
//  SettingsView.swift
//  RoofScan
//
//  19 — Settings. Units, currency, labor rate, roof presets, theme, reminders,
//  backup and data export. Every control has real, persisted effect.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: RoofStore
    @EnvironmentObject private var settings: AppSettings
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = true

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showReset = false
    @State private var backupFlash = false

    var body: some View {
        ScreenScaffold(title: "Settings", subtitle: "Units, presets, theme & data") {

            // Appearance
            CardView {
                SectionHeader(title: "Appearance", icon: "paintbrush.fill")
                HStack(spacing: 8) {
                    ForEach(ThemeMode.allCases) { mode in
                        Chip(label: mode.label, icon: mode.icon, selected: settings.themeMode == mode) {
                            withAnimation { settings.themeMode = mode }
                        }
                    }
                }
            }

            // Units & money
            CardView {
                SectionHeader(title: "Units & currency", icon: "ruler.fill")
                HStack(spacing: 8) {
                    ForEach(UnitSystem.allCases) { u in
                        Chip(label: u.lengthUnit + " / " + u.areaUnit, selected: settings.unitSystem == u) {
                            settings.unitSystem = u
                        }
                    }
                }
                Divider().background(Theme.divider)
                Text("Currency").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AppSettings.currencyOptions, id: \.self) { c in
                            Chip(label: c, selected: settings.currency == c) { settings.currency = c }
                        }
                    }
                }
                LabeledSlider(label: "Labor rate", value: $settings.hourlyRate, range: 10...200, step: 5,
                              unit: "\(settings.currency)/hr", format: "%.0f")
            }

            // Roof presets (affect estimates live)
            CardView {
                SectionHeader(title: "Roof presets", subtitle: "Drives estimates & defaults", icon: "house.fill")
                Text("Roof type").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(RoofType.allCases) { t in
                        Chip(label: t.label, icon: t.icon, selected: store.project.roofType == t) {
                            store.project.roofType = t
                        }
                    }
                }
                Text("Covering").font(.rsCaption()).foregroundColor(Theme.textSecondary).padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Covering.allCases) { c in
                        Chip(label: c.label, selected: store.project.covering == c) {
                            store.project.covering = c
                        }
                    }
                }
                LabeledSlider(label: "Roof age", value: Binding(
                    get: { Double(store.project.ageYears) },
                    set: { store.project.ageYears = Int($0) }),
                    range: 0...40, step: 1, unit: "yr", format: "%.0f")
                Text("Climate load").font(.rsCaption()).foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ClimateLoad.allCases) { c in
                        Chip(label: c.label, icon: c.icon, selected: store.project.climateLoads.contains(c),
                             tint: Theme.signalOrange) {
                            if store.project.climateLoads.contains(c) { store.project.climateLoads.remove(c) }
                            else { store.project.climateLoads.insert(c) }
                        }
                    }
                }
            }

            // Notifications
            NavigationLink(destination: RemindersView()) {
                NavRow(icon: "bell.fill", title: "Reminders", subtitle: "Seasonal & post-storm alerts", tint: Theme.amber)
            }

            // Data
            CardView {
                SectionHeader(title: "Data", icon: "externaldrive.fill")
                Button { backup() } label: {
                    settingRow(icon: "tray.and.arrow.down.fill",
                               title: backupFlash ? "Backed up ✓" : "Backup now",
                               subtitle: settings.lastBackup.map { "Last: \(dateString($0))" } ?? "No backup yet",
                               tint: Theme.ok)
                }
                Divider().background(Theme.divider)
                Button { exportData() } label: {
                    settingRow(icon: "square.and.arrow.up.fill", title: "Export data",
                               subtitle: "Share the roof project JSON", tint: Theme.primary)
                }
                Divider().background(Theme.divider)
                Button { hasOnboarded = false } label: {
                    settingRow(icon: "arrow.counterclockwise", title: "Replay setup",
                               subtitle: "Re-run the onboarding wizard", tint: Theme.ridge)
                }
                Divider().background(Theme.divider)
                Button { showReset = true } label: {
                    settingRow(icon: "trash.fill", title: "Reset all data",
                               subtitle: "Delete every slope, defect & photo", tint: Theme.critical)
                }
            }

            // About
            CardView {
                SectionHeader(title: "About", icon: "info.circle.fill")
                KeyValueRow(key: "Roof Scan", value: "v1.0")
                Text("Estimates support — they don't replace — an on-site inspection by a qualified roofer. Only climb when it is safe to do so.")
                    .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .alert(isPresented: $showReset) {
            Alert(title: Text("Reset all data?"),
                  message: Text("This permanently deletes all slopes, defects, photos and history."),
                  primaryButton: .destructive(Text("Reset")) { store.resetAll() },
                  secondaryButton: .cancel())
        }
    }

    private func settingRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rsBody()).foregroundColor(Theme.textPrimary)
                Text(subtitle).font(.rsCaption()).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textDisabled)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func backup() {
        store.saveNow()
        let stamp = String(Int(Date().timeIntervalSince1970))
        _ = PersistenceService.shared.backup(store.project, stamp: stamp)
        settings.lastBackup = Date()
        withAnimation { backupFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { backupFlash = false }
    }

    private func exportData() {
        if let url = PersistenceService.shared.exportDataURL(store.project) {
            shareURL = url
            showShare = true
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
