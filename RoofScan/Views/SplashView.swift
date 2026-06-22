//
//  SplashView.swift
//  RoofScan
//
//  Thematic splash: a gable roof draws itself in blue, a droplet rolls down the
//  slope leaving a glowing trail, then the wordmark springs in. ≥2.5s, three
//  simultaneously animated layers, a designed implode-exit, and every looping
//  animation is reset in .onDisappear to prevent leaks into the main app.
//

import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    @State private var isVisible = true
    @State private var bgPulse = false        // layer 1 loop
    @State private var drawProgress: CGFloat = 0
    @State private var dropT: CGFloat = 0      // layer 2 loop
    @State private var logoIn = false          // layer 3 entrance
    @State private var exiting = false
    @State private var coordinator: Timer?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let apex = CGPoint(x: w * 0.5, y: h * 0.30)
            let leftEave = CGPoint(x: w * 0.20, y: h * 0.50)
            let rightEave = CGPoint(x: w * 0.80, y: h * 0.50)

            ZStack {
                // Layer 1 — background gradient + breathing glow
                Theme.bgGradient.ignoresSafeArea()
                RadialGradient(colors: [Theme.blueGlow, .clear],
                               center: .center, startRadius: 8,
                               endRadius: bgPulse ? 460 : 300)
                    .ignoresSafeArea()
                    .opacity(0.45)
                rainLayer(size: geo.size)

                // Layer 2 — roof line draws in, droplet rolls down with a trail
                RoofOutline(apex: apex, left: leftEave, right: rightEave)
                    .trim(from: 0, to: drawProgress)
                    .stroke(Theme.ridge, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .rsGlow(Theme.ridge.opacity(0.7), radius: 10)

                if drawProgress >= 0.99 {
                    LineSegment(a: apex, b: rightEave)
                        .trim(from: max(0, dropT - 0.28), to: dropT)
                        .stroke(Theme.valley, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rsGlow(Theme.dropGlow, radius: 6)

                    Circle()
                        .fill(Theme.valley)
                        .frame(width: 15, height: 15)
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                        .rsGlow(Theme.dropGlow, radius: 9)
                        .position(lerpPoint(apex, rightEave, dropT))
                }

                // Layer 3 — wordmark
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.primaryGradient)
                            .frame(width: 84, height: 84)
                            .rsGlow(Theme.blueGlow, radius: 18)
                        Image(systemName: "house.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.amberLight)
                            .offset(x: 14, y: 6)
                    }
                    Text("Roof Scan")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("Find the leak before it spreads.")
                        .font(.rsBody())
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, h * 0.40)
                .opacity(logoIn ? 1 : 0)
                .scaleEffect(logoIn ? (exiting ? 1.5 : 1) : 0.82)
            }
            .scaleEffect(exiting ? 1.12 : 1)
            .opacity(exiting ? 0 : 1)
            .onAppear { start() }
            .onDisappear { stopAll() }
        }
    }

    // Soft falling-rain ambiance (deterministic positions, gentle loop).
    private func rainLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                let x = CGFloat((i * 53) % Int(max(1, size.width)))
                Capsule()
                    .fill(Theme.dropGlow)
                    .frame(width: 2, height: 14)
                    .position(x: x, y: bgPulse ? size.height * 0.9 : -20)
                    .opacity(0.35)
                    .animation(.linear(duration: 2.4)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.16), value: bgPulse)
            }
        }
        .allowsHitTesting(false)
    }

    private func start() {
        isVisible = true
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bgPulse = true }
        withAnimation(.easeInOut(duration: 1.2).delay(0.25)) { drawProgress = 1 }
        withAnimation(.easeIn(duration: 1.3).repeatForever(autoreverses: false).delay(1.5)) { dropT = 1 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.5)) { logoIn = true }

        coordinator = Timer.scheduledTimer(withTimeInterval: 2.7, repeats: false) { _ in
            guard isVisible else { return }
            withAnimation(.easeIn(duration: 0.5)) { exiting = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onComplete() }
        }
    }

    private func stopAll() {
        isVisible = false
        coordinator?.invalidate()
        coordinator = nil
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            bgPulse = false; dropT = 0; drawProgress = 0; logoIn = false; exiting = false
        }
    }
}

// MARK: - Shapes

private struct RoofOutline: Shape {
    let apex: CGPoint, left: CGPoint, right: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: left)
        p.addLine(to: apex)
        p.addLine(to: right)
        return p
    }
}

private struct LineSegment: Shape {
    let a: CGPoint, b: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }
}

private func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}
