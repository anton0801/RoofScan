//
//  ContentView.swift
//  RoofScan
//
//  Root router: Splash → Onboarding (first launch only) → Main app.
//  No auth / welcome / profile screens anywhere.
//

import SwiftUI

struct RootRouterView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                }
                .transition(.opacity)
            } else if !hasOnboarded {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
    }
}
