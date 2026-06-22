//
//  Buttons.swift
//  RoofScan
//
//  Custom button styles + reusable button views (scale-on-tap spring).
//

import SwiftUI

// MARK: - Pressable spring style

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Primary

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.rsBodyBold())
            }
            .foregroundColor(Theme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: RSLayout.controlRadius, style: .continuous)
                    .fill(Theme.primaryGradient)
            )
            .rsGlow(Theme.blueGlow, radius: enabled ? 12 : 0)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

// MARK: - Secondary

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.rsBodyBold())
            }
            .foregroundColor(Color(hex: 0xDCE7FF))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: RSLayout.controlRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RSLayout.controlRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Danger

struct DangerButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.rsBodyBold())
            }
            .foregroundColor(Theme.onDanger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: RSLayout.controlRadius, style: .continuous)
                    .fill(Theme.critical)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Icon action button (compact, used in toolbars/headers)

struct IconActionButton: View {
    let icon: String
    var tint: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.15)))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Quick action tile (used on Roof Map / hubs)

struct QuickActionTile: View {
    let icon: String
    let title: String
    var tint: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.rsCaption())
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.bgSoft))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Navigation row (used in hub lists)

struct NavRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = Theme.primary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rsBodyBold()).foregroundColor(Theme.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle).font(.rsCaption()).foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textDisabled)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}
