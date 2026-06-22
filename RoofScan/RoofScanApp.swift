//
//  RoofScanApp.swift
//  RoofScan
//
//  App entry. Injects the global store + settings and applies the theme.
//

import SwiftUI

@main
struct RoofScanApp: App {
    @StateObject private var store = RoofStore()
    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(settings.themeMode.colorScheme)
                .onAppear { store.garbageCollectPhotos() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { store.saveNow() }
        }
    }
}
