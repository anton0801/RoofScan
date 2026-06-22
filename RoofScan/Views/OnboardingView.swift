//
//  OnboardingView.swift
//  RoofScan
//
//  Interactive 4-step setup. Custom GeometryReader pager (button-driven, so inner
//  gestures never fight a swipe). Each step has a distinct interaction:
//   1 Roof type — tap to select (+ particle burst)
//   2 Covering  — drag a droplet across the sample
//   3 Roof age  — drag a scrubber that ages a parallax roof
//   4 Climate   — long-press to toggle each load
//  Choices commit into RoofStore; gate via @AppStorage("hasCompletedOnboarding").
//

import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var store: RoofStore
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @StateObject private var vm = OnboardingViewModel()

    private let ctas = ["Set Roof", "Set Covering", "Set Age", "Start Scan"]

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip (always visible)
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.rsBodyBold())
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                }

                // Custom pager
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        RoofTypeStep(vm: vm).frame(width: geo.size.width)
                        CoveringStep(vm: vm).frame(width: geo.size.width)
                        AgeStep(vm: vm).frame(width: geo.size.width)
                        ClimateStep(vm: vm).frame(width: geo.size.width)
                    }
                    .offset(x: -CGFloat(vm.step) * geo.size.width)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: vm.step)
                }

                // Dots
                HStack(spacing: 8) {
                    ForEach(0...vm.lastStep, id: \.self) { i in
                        Capsule()
                            .fill(i == vm.step ? Theme.primary : Theme.border)
                            .frame(width: i == vm.step ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.step)
                    }
                }
                .padding(.vertical, 14)

                // Back + CTA (always visible)
                HStack(spacing: 12) {
                    if vm.step > 0 {
                        SecondaryButton(title: "Back", icon: "chevron.left") { vm.back() }
                            .frame(width: 120)
                    }
                    PrimaryButton(title: ctas[vm.step],
                                  icon: vm.step == vm.lastStep ? "scope" : "chevron.right") {
                        advance()
                    }
                }
                .padding(.horizontal, RSLayout.screenPadding)
                .padding(.bottom, 12)
            }
        }
    }

    private func advance() {
        if vm.step < vm.lastStep { vm.next() } else { finish() }
    }

    private func finish() {
        vm.commit(to: store)
        store.seedDefaultReminders()
        withAnimation(.easeInOut(duration: 0.4)) { hasOnboarded = true }
    }
}

// MARK: - Step 1: Roof type (tap + particle burst)

private struct RoofTypeStep: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var burst = 0

    var body: some View {
        StepScaffold(icon: "house.fill",
                     title: "Roof Type",
                     blurb: "Sets the base geometry and the nodes we'll check.") {
            ZStack {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(RoofType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                vm.roofType = type
                            }
                            burst += 1
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(vm.roofType == type ? .white : Theme.highlight)
                                Text(type.label).font(.rsBodyBold())
                                    .foregroundColor(vm.roofType == type ? .white : Theme.textPrimary)
                                Text(type.detail).font(.system(size: 10))
                                    .foregroundColor(vm.roofType == type ? .white.opacity(0.85) : Theme.textSecondary)
                                    .multilineTextAlignment(.center).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(vm.roofType == type ? Theme.primary : Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(vm.roofType == type ? Theme.highlight : Theme.border, lineWidth: 1))
                            .scaleEffect(vm.roofType == type ? 1.03 : 1)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                BurstView(trigger: burst).allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Step 2: Covering (drag a droplet)

private struct CoveringStep: View {
    @ObservedObject var vm: OnboardingViewModel
    @State private var dropPos: CGSize = .zero
    @State private var beads: [Bead] = []

    struct Bead: Identifiable { let id = UUID(); var pos: CGSize }

    var body: some View {
        StepScaffold(icon: "square.grid.3x3.fill",
                     title: "Covering",
                     blurb: "Drag the droplet across the sample — picks the wear curve for life estimates.") {
            VStack(spacing: 16) {
                // Drag surface
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(coveringColor.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border, lineWidth: 1))
                        .frame(height: 130)
                    ForEach(beads) { b in
                        Circle().fill(Theme.dropGlow).frame(width: 8, height: 8).offset(b.pos)
                    }
                    Circle()
                        .fill(Theme.valley)
                        .frame(width: 26, height: 26)
                        .overlay(Image(systemName: "drop.fill").font(.system(size: 12)).foregroundColor(.white))
                        .rsGlow(Theme.dropGlow, radius: 8)
                        .offset(dropPos)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    dropPos = v.translation
                                    if beads.count < 30 { beads.append(Bead(pos: v.translation)) }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { dropPos = .zero }
                                    withAnimation(.easeOut(duration: 0.6)) { beads = [] }
                                }
                        )
                }
                .frame(height: 130)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Covering.allCases) { c in
                        Chip(label: c.label, icon: c.icon, selected: vm.covering == c) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.covering = c }
                        }
                    }
                }
                Text("Baseline life: \(vm.covering.baselineLife) yr")
                    .font(.rsCaption()).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var coveringColor: Color {
        switch vm.covering {
        case .shingle: return Theme.amber
        case .metal: return Theme.highlight
        case .tile: return Theme.signalOrange
        case .slate: return Theme.textSecondary
        case .bitumen: return Theme.critical
        case .membrane: return Theme.ridge
        }
    }
}

// MARK: - Step 3: Roof age (drag scrubber + parallax aging)

private struct AgeStep: View {
    @ObservedObject var vm: OnboardingViewModel
    private var frac: Double { vm.age / 40 }

    var body: some View {
        StepScaffold(icon: "calendar",
                     title: "Roof Age",
                     blurb: "Drag to set how long the covering has been up there.") {
            VStack(spacing: 18) {
                // Parallax aging scene
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.bgSoft, Theme.bgDepth], startPoint: .top, endPoint: .bottom))
                        .frame(height: 150)
                    // roof, color ages from fresh blue-green to worn grey-brown
                    AgingRoof(frac: frac)
                        .frame(width: 200, height: 90)
                        .offset(y: 8)
                    // moss/wear specks grow with age
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(Theme.ok.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .offset(x: CGFloat((i * 37) % 160) - 80,
                                    y: CGFloat((i * 53) % 50) - 10)
                            .opacity(frac)
                    }
                }
                .frame(height: 150)
                .clipped()

                // Custom drag scrubber
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.bgSoft).frame(height: 10)
                        Capsule().fill(Theme.primaryGradient)
                            .frame(width: max(10, CGFloat(frac) * g.size.width), height: 10)
                        Circle()
                            .fill(.white)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Theme.primary, lineWidth: 4))
                            .rsGlow(Theme.blueGlow, radius: 6)
                            .position(x: max(15, min(g.size.width - 15, CGFloat(frac) * g.size.width)), y: 5)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        let f = max(0, min(1, v.location.x / g.size.width))
                                        vm.age = (f * 40).rounded()
                                    }
                            )
                    }
                }
                .frame(height: 30)

                Text("\(Int(vm.age)) years old")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }
}

private struct AgingRoof: View {
    let frac: Double
    var body: some View {
        let fresh = Color(hex: 0x2F6BFF)
        let worn = Color(hex: 0x6B5B4A)
        ZStack {
            Triangle()
                .fill(Color.blend(fresh, worn, t: frac))
            Triangle()
                .stroke(Theme.ridge.opacity(1 - frac * 0.7), lineWidth: 2)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Step 4: Climate (long-press to toggle)

private struct ClimateStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        StepScaffold(icon: "cloud.sun.rain.fill",
                     title: "Climate Load",
                     blurb: "Press & hold each load that hits this roof — tunes risk weighting and reminder cadence.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ClimateLoad.allCases) { load in
                    let on = vm.climate.contains(load)
                    VStack(spacing: 8) {
                        Image(systemName: load.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(on ? .white : Theme.highlight)
                        Text(load.label).font(.rsBodyBold())
                            .foregroundColor(on ? .white : Theme.textPrimary)
                        Text("−\(String(format: "%.1f", load.lifePenalty)) yr life")
                            .font(.system(size: 10))
                            .foregroundColor(on ? .white.opacity(0.85) : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 104)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(on ? Theme.signalOrange : Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(on ? Theme.amberLight : Theme.border, lineWidth: 1))
                    .scaleEffect(on ? 1.03 : 1)
                    .onLongPressGesture(minimumDuration: 0.35) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            vm.toggleClimate(load)
                        }
                    }
                }
            }
            if vm.climate.isEmpty {
                Text("Optional — leave empty for a mild climate.")
                    .font(.rsCaption()).foregroundColor(Theme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Shared step shell + burst

private struct StepScaffold<Content: View>: View {
    let icon: String
    let title: String
    let blurb: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(Theme.primary.opacity(0.16)).frame(width: 70, height: 70)
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Theme.highlight)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text(title).font(.rsHero()).foregroundColor(Theme.textPrimary)
                Text(blurb).font(.rsBody()).foregroundColor(Theme.textSecondary)
                content()
            }
            .padding(RSLayout.screenPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct BurstView: View {
    let trigger: Int
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi
                Circle()
                    .fill(i % 2 == 0 ? Theme.amberLight : Theme.highlight)
                    .frame(width: 7, height: 7)
                    .offset(x: go ? CGFloat(cos(angle)) * 90 : 0,
                            y: go ? CGFloat(sin(angle)) * 90 : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .onChange(of: trigger) { _ in
            go = false
            withAnimation(.easeOut(duration: 0.6)) { go = true }
        }
    }
}

// MARK: - Color blend helper

extension Color {
    static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let ct = max(0, min(1, t))
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * CGFloat(ct)),
                     green: Double(g1 + (g2 - g1) * CGFloat(ct)),
                     blue: Double(b1 + (b2 - b1) * CGFloat(ct)),
                     opacity: 1)
    }
}
