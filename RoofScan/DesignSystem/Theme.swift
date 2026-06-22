//
//  Theme.swift
//  RoofScan
//
//  Centralized design system: palette, dynamic light/dark colors,
//  typography, layout constants and severity/status color mapping.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color from hex

extension Color {
    /// Build a Color from a 0xRRGGBB hex literal.
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: alpha)
    }

    /// A color that resolves differently for dark vs light interface styles.
    /// One mechanism gives the whole app automatic theming — every `Theme`
    /// token below flips when `preferredColorScheme` changes.
    static func dynamic(dark: UInt, light: UInt, alpha: Double = 1) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: CGFloat(alpha))
        })
    }
}

// MARK: - Theme palette

/// All palette tokens. Brand hues stay constant across schemes; backgrounds
/// and text invert. Reference these everywhere — never hardcode a hex in a view.
enum Theme {
    // Backgrounds
    static let bg          = Color.dynamic(dark: 0x0E1726, light: 0xF2F6FC)
    static let bgDepth     = Color.dynamic(dark: 0x08101C, light: 0xE5ECF7)
    static let bgSoft      = Color.dynamic(dark: 0x15213A, light: 0xFFFFFF)

    // Cards
    static let card        = Color.dynamic(dark: 0x182740, light: 0xFFFFFF)
    static let cardHover   = Color.dynamic(dark: 0x213354, light: 0xEDF2FB)
    static let border      = Color.dynamic(dark: 0x2C3F66, light: 0xD3DCEC)
    static let divider     = Color.dynamic(dark: 0x78AAFF, light: 0x14284F, alpha: 0.12)

    // Primary (brand blue — constant)
    static let primary       = Color(hex: 0x2F6BFF)
    static let primaryActive = Color(hex: 0x1E54E6)
    static let highlight     = Color(hex: 0x6E9BFF)

    // Accents
    static let amber       = Color(hex: 0xF59E0B)
    static let amberLight  = Color(hex: 0xFBBF24)
    static let signalOrange = Color(hex: 0xF97316)

    // Structural lines (ridge / valley)
    static let ridge       = Color(hex: 0x38BDF8)
    static let valley      = Color(hex: 0x7DD3FC)

    // Status
    static let ok          = Color(hex: 0x22C55E)
    static let inProgress  = Color(hex: 0x2F6BFF)
    static let warning     = Color(hex: 0xF59E0B)
    static let critical    = Color(hex: 0xEF4444)

    // Text
    static let textPrimary   = Color.dynamic(dark: 0xEAF1FF, light: 0x0E1726)
    static let textSecondary = Color.dynamic(dark: 0xA9BCDC, light: 0x4B5C77)
    static let textDisabled  = Color.dynamic(dark: 0x647499, light: 0x97A4BC)

    // On-color text
    static let onPrimary   = Color(hex: 0xEAF1FF)
    static let onDanger    = Color(hex: 0xFFFFFF)

    // Glows / effects
    static let blueGlow    = Color(hex: 0x2F6BFF, alpha: 0.40)
    static let amberGlow   = Color(hex: 0xF59E0B, alpha: 0.30)
    static let dropGlow    = Color(hex: 0x7DD3FC, alpha: 0.30)

    // Gradients
    static var bgGradient: LinearGradient {
        LinearGradient(colors: [bgDepth, bg, bgSoft],
                       startPoint: .top, endPoint: .bottom)
    }
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [highlight, primary, primaryActive],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var amberGradient: LinearGradient {
        LinearGradient(colors: [amberLight, amber, signalOrange],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Layout constants

enum RSLayout {
    static let screenPadding: CGFloat = 16
    static let cardRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let spacing: CGFloat = 12
    static let spacingS: CGFloat = 8
    static let spacingL: CGFloat = 20
    static let tabBarHeight: CGFloat = 64
    static let shadow = Color.black.opacity(0.45)
}

// MARK: - Typography

extension Font {
    static func rsHero() -> Font   { .system(size: 34, weight: .heavy, design: .rounded) }
    static func rsTitle() -> Font  { .system(size: 24, weight: .bold, design: .rounded) }
    static func rsHeadline() -> Font { .system(size: 18, weight: .semibold, design: .rounded) }
    static func rsBody() -> Font   { .system(size: 15, weight: .regular, design: .default) }
    static func rsBodyBold() -> Font { .system(size: 15, weight: .semibold, design: .default) }
    static func rsCaption() -> Font { .system(size: 12, weight: .medium, design: .default) }
    static func rsMono(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .monospaced) }
}

// MARK: - Severity & status colors

enum SeverityPalette {
    /// Severity 1..5 → green → amber → orange → red heat ramp.
    static func color(severity: Int) -> Color {
        switch max(1, min(5, severity)) {
        case 1: return Theme.ok
        case 2: return Color(hex: 0x84CC16)   // lime
        case 3: return Theme.amber
        case 4: return Theme.signalOrange
        default: return Theme.critical
        }
    }

    static func color(for status: DefectStatus) -> Color {
        switch status {
        case .active:     return Theme.critical
        case .inProgress: return Theme.inProgress
        case .repaired:   return Theme.ok
        }
    }

    /// Health 0..100 → red → amber → green.
    static func health(_ pct: Int) -> Color {
        switch pct {
        case ..<35: return Theme.critical
        case ..<55: return Theme.signalOrange
        case ..<75: return Theme.amber
        default:    return Theme.ok
        }
    }

    static func condition(_ c: ConditionState) -> Color {
        switch c {
        case .good:    return Theme.ok
        case .worn:    return Theme.amber
        case .cracked: return Theme.signalOrange
        case .failed:  return Theme.critical
        }
    }
}

// MARK: - Reusable view modifiers

extension View {
    /// Apply the standard screen background (ignoring safe area).
    func rsScreenBackground() -> some View {
        background(Theme.bgGradient.ignoresSafeArea())
    }

    /// Subtle outer glow used on highlighted elements.
    func rsGlow(_ color: Color, radius: CGFloat = 14) -> some View {
        shadow(color: color, radius: radius, x: 0, y: 0)
    }
}
