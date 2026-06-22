//
//  Cards.swift
//  RoofScan
//
//  Card container, section headers, stat pills, banners and empty states.
//

import SwiftUI

// MARK: - Card

struct CardView<Content: View>: View {
    var padding: CGFloat = RSLayout.cardPadding
    var tint: Color = Theme.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RSLayout.cardRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(color: RSLayout.shadow, radius: 10, x: 0, y: 6)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.highlight)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rsHeadline())
                    .foregroundColor(Theme.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.rsCaption())
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Stat pill

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = Theme.primary

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(.rsCaption())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.bgSoft))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Info / disclaimer banner

struct InfoBanner: View {
    let text: String
    var icon: String = "exclamationmark.triangle.fill"
    var tint: Color = Theme.amber

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .font(.system(size: 14, weight: .bold))
            Text(text)
                .font(.rsCaption())
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tint.opacity(0.30), lineWidth: 1))
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(Theme.textDisabled)
            Text(title)
                .font(.rsHeadline())
                .foregroundColor(Theme.textPrimary)
            Text(message)
                .font(.rsBody())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(title: actionTitle, icon: "plus", action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

// MARK: - Key/value row

struct KeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.textPrimary

    var body: some View {
        HStack {
            Text(key).font(.rsBody()).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).font(.rsBodyBold()).foregroundColor(valueColor)
        }
        .padding(.vertical, 2)
    }
}
