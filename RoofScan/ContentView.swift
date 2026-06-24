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
    
    @StateObject private var store = RoofStore()
    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if !hasOnboarded {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .environmentObject(store)
        .environmentObject(settings)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .onAppear { store.garbageCollectPhotos() }
        .onChange(of: scenePhase) { phase in
            if phase == .background { store.saveNow() }
        }
    }
}
