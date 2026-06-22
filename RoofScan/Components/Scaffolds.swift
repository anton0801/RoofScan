//
//  Scaffolds.swift
//  RoofScan
//
//  Standard screen + sheet shells: dark gradient background, scrollable body,
//  a styled hero title, and (for sheets) a titled bar with Cancel/Save.
//

import SwiftUI
import UIKit

// MARK: - Screen (inside a tab's NavigationView)

struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.rsTitle()).foregroundColor(Theme.textPrimary)
                        if let subtitle = subtitle {
                            Text(subtitle).font(.rsBody()).foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 4)
                    content()
                }
                .padding(RSLayout.screenPadding)
                .padding(.bottom, 96)   // clear the floating tab bar
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sheet (own NavigationView with Cancel/Save)

struct SheetScaffold<Content: View>: View {
    let title: String
    var saveLabel: String = "Save"
    var canSave: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void
    let content: () -> Content

    init(title: String, saveLabel: String = "Save", canSave: Bool = true,
         onCancel: @escaping () -> Void, onSave: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.saveLabel = saveLabel
        self.canSave = canSave
        self.onCancel = onCancel
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        content()
                    }
                    .padding(RSLayout.screenPadding)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel).foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveLabel, action: onSave)
                        .font(.rsBodyBold())
                        .foregroundColor(canSave ? Theme.primary : Theme.textDisabled)
                        .disabled(!canSave)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
