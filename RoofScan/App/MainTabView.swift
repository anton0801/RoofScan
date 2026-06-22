//
//  MainTabView.swift
//  RoofScan
//
//  Custom 5-tab shell (Map / Inspect / Estimate / Reports / Settings).
//  Each tab hosts its own NavigationView so pushes work on iOS 14/15.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selected = 0

    init() { Self.configureNavBar() }

    /// Transparent dark navigation bar with white titles and a blue back button.
    static func configureNavBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.18, green: 0.42, blue: 1, alpha: 1)
    }

    private let tabs: [(icon: String, title: String)] = [
        ("square.grid.3x3.fill", "Map"),
        ("magnifyingglass", "Inspect"),
        ("function", "Estimate"),
        ("doc.text.fill", "Reports"),
        ("gearshape.fill", "Settings")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            tabBar
        }
    }

    @ViewBuilder private var content: some View {
        switch selected {
        case 0: NavigationView { RoofMapView() }.navigationViewStyle(.stack)
        case 1: NavigationView { InspectHubView() }.navigationViewStyle(.stack)
        case 2: NavigationView { EstimateHubView() }.navigationViewStyle(.stack)
        case 3: NavigationView { ReportsView() }.navigationViewStyle(.stack)
        default: NavigationView { SettingsView() }.navigationViewStyle(.stack)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = idx }
                } label: {
                    TabBarButton(icon: tab.icon, title: tab.title, selected: selected == idx)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .background(
            Theme.bgDepth
                .overlay(Rectangle().fill(Theme.divider).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(selected ? Theme.primary : Theme.textDisabled)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .overlay(
            Capsule()
                .fill(Theme.primary)
                .frame(width: selected ? 22 : 0, height: 3)
                .offset(y: -10),
            alignment: .top
        )
        .scaleEffect(selected ? 1.05 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

// MARK: - Inspect hub

struct InspectHubView: View {
    var body: some View {
        ScreenScaffold(title: "Inspect", subtitle: "Diagnose leaks, joints and drainage") {
            VStack(spacing: 12) {
                NavigationLink(destination: LeakTraceView()) {
                    NavRow(icon: "drop.degreesign.fill", title: "Leak Trace",
                           subtitle: "Find the entry point up-slope", tint: Theme.primary)
                }
                NavigationLink(destination: FlashingJointsView()) {
                    NavRow(icon: "building.2.fill", title: "Flashing & Joints",
                           subtitle: "Penetrations, chimneys, walls", tint: Theme.amber)
                }
                NavigationLink(destination: GutterDrainageView()) {
                    NavRow(icon: "drop.fill", title: "Gutter & Drainage",
                           subtitle: "Clogs, sags, overflow points", tint: Theme.ridge)
                }
                NavigationLink(destination: StormCheckView()) {
                    NavRow(icon: "cloud.bolt.rain.fill", title: "Storm Check",
                           subtitle: "Fast post-storm walk-around", tint: Theme.signalOrange)
                }
                NavigationLink(destination: InspectionRoundView()) {
                    NavRow(icon: "checklist", title: "Inspection Round",
                           subtitle: "Scheduled full walk-through", tint: Theme.ok)
                }
                NavigationLink(destination: SafetyNotesView()) {
                    NavRow(icon: "exclamationmark.shield.fill", title: "Safety Notes",
                           subtitle: "Before you climb", tint: Theme.critical)
                }
            }
        }
    }
}

// MARK: - Estimate hub

struct EstimateHubView: View {
    @EnvironmentObject var store: RoofStore
    var body: some View {
        ScreenScaffold(title: "Estimate", subtitle: "Service life, materials and cost") {
            VStack(spacing: 12) {
                NavigationLink(destination: ServiceLifeView()) {
                    NavRow(icon: "calendar.badge.clock", title: "Service-Life Estimate",
                           subtitle: "Years until replacement", tint: Theme.primary)
                }
                NavigationLink(destination: MaterialEstimateView()) {
                    NavRow(icon: "shippingbox.fill", title: "Material Estimate",
                           subtitle: "Take-off by area & covering", tint: Theme.amber)
                }
                NavigationLink(destination: RepairCostView()) {
                    NavRow(icon: "creditcard.fill", title: "Repair Cost",
                           subtitle: "Material + labor by defect", tint: Theme.ok)
                }
            }
        }
    }
}
