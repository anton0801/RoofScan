//
//  AppSettings.swift
//  RoofScan
//
//  App-wide preferences (units, currency, hourly rate, theme) exposed as an
//  @EnvironmentObject. Each property persists to UserDefaults on change —
//  functionally equivalent to @AppStorage but shareable across the app.
//

import SwiftUI
import Combine

final class AppSettings: ObservableObject {

    private enum Key {
        static let units = "settings.units"
        static let currency = "settings.currency"
        static let hourlyRate = "settings.hourlyRate"
        static let theme = "settings.theme"
        static let notifications = "settings.notificationsEnabled"
        static let lastBackup = "settings.lastBackup"
    }

    static let currencyOptions = ["$", "€", "£", "₽", "¥", "₴", "zł"]

    @Published var unitSystem: UnitSystem { didSet { d.set(unitSystem.rawValue, forKey: Key.units) } }
    @Published var currency: String { didSet { d.set(currency, forKey: Key.currency) } }
    @Published var hourlyRate: Double { didSet { d.set(hourlyRate, forKey: Key.hourlyRate) } }
    @Published var themeMode: ThemeMode { didSet { d.set(themeMode.rawValue, forKey: Key.theme) } }
    @Published var notificationsEnabled: Bool { didSet { d.set(notificationsEnabled, forKey: Key.notifications) } }
    @Published var lastBackup: Date? { didSet { d.set(lastBackup, forKey: Key.lastBackup) } }

    private let d = UserDefaults.standard

    init() {
        unitSystem = UnitSystem(rawValue: d.string(forKey: Key.units) ?? "") ?? .metric
        currency = d.string(forKey: Key.currency) ?? "$"
        let rate = d.double(forKey: Key.hourlyRate)
        hourlyRate = rate > 0 ? rate : 45
        themeMode = ThemeMode(rawValue: d.string(forKey: Key.theme) ?? "") ?? .dark
        notificationsEnabled = d.object(forKey: Key.notifications) as? Bool ?? false
        lastBackup = d.object(forKey: Key.lastBackup) as? Date
    }

    func resetToDefaults() {
        unitSystem = .metric
        currency = "$"
        hourlyRate = 45
        themeMode = .dark
    }

    // MARK: - Display helpers

    func length(_ meters: Double) -> String {
        String(format: "%.1f %@", meters * unitSystem.lengthFactor, unitSystem.lengthUnit)
    }
    func area(_ m2: Double) -> String {
        String(format: "%.1f %@", m2 * unitSystem.areaFactor, unitSystem.areaUnit)
    }
    func money(_ value: Double) -> String {
        "\(currency)\(String(format: "%.0f", value))"
    }
}
