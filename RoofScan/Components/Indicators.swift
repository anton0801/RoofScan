//
//  Indicators.swift
//  RoofScan
//
//  Visual status indicators: health ring, severity / status / condition badges,
//  the pulsing roof-map marker.
//

import SwiftUI

// MARK: - Health ring

struct HealthRing: View {
    let percent: Int
    var size: CGFloat = 116
    var lineWidth: CGFloat = 12

    @State private var shown: CGFloat = 0

    var body: some View {
        let clamped = max(0, min(100, percent))
        ZStack {
            Circle().stroke(Theme.bgSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(SeverityPalette.health(clamped),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .rsGlow(SeverityPalette.health(clamped).opacity(0.5), radius: 8)
            VStack(spacing: 0) {
                Text("\(clamped)")
                    .font(.system(size: size * 0.30, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text("HEALTH")
                    .font(.system(size: size * 0.085, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                shown = CGFloat(clamped) / 100
            }
        }
        .onChange(of: percent) { new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                shown = CGFloat(max(0, min(100, new))) / 100
            }
        }
    }
}

// MARK: - Badges

struct SeverityBadge: View {
    let severity: Int
    var body: some View {
        let c = SeverityPalette.color(severity: severity)
        Text("Sev \(severity)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(c)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(c.opacity(0.18)))
            .overlay(Capsule().stroke(c.opacity(0.4), lineWidth: 1))
    }
}

struct StatusBadge: View {
    let status: DefectStatus
    var body: some View {
        let c = SeverityPalette.color(for: status)
        Text(status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(c)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(c.opacity(0.18)))
    }
}

struct ConditionBadge: View {
    let condition: ConditionState
    var body: some View {
        let c = SeverityPalette.condition(condition)
        Text(condition.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(c)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(c.opacity(0.18)))
    }
}

struct TierBadge: View {
    let tier: RecommendationTier
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tier.icon).font(.system(size: 12, weight: .bold))
            Text(tier.label).font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(tier.color))
        .rsGlow(tier.color.opacity(0.4), radius: 8)
    }
}

// MARK: - Pulsing marker (roof map)

struct PulsingMarker: View {
    let color: Color
    var size: CGFloat = 24
    var pulse: Bool = true

    @State private var animate = false

    var body: some View {
        ZStack {
            if pulse {
                Circle()
                    .fill(color.opacity(0.45))
                    .frame(width: size, height: size)
                    .scaleEffect(animate ? 2.4 : 1)
                    .opacity(animate ? 0 : 0.6)
            }
            Circle()
                .fill(color)
                .frame(width: size * 0.55, height: size * 0.55)
                .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                .rsGlow(color.opacity(0.7), radius: 6)
        }
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .onDisappear { animate = false }
    }
}

// MARK: - Small status dot

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 10
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Horizontal progress bar

struct ProgressBar: View {
    let fraction: Double      // 0…1
    var tint: Color = Theme.primary
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.bgSoft)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
