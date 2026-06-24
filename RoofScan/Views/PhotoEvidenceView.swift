//
//  PhotoEvidenceView.swift
//  RoofScan
//
//  13 — Photo Evidence. All photos grouped by slope, with a viewer that lets you
//  drag an arrow onto the damage boundary and edit the caption.
//

import SwiftUI
import WebKit

struct PhotoEvidenceView: View {
    @EnvironmentObject private var store: RoofStore
    @State private var viewing: PhotoEvidence?

    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScreenScaffold(title: "Photo Evidence", subtitle: "\(store.project.photos.count) photos") {
            if store.project.photos.isEmpty {
                CardView { EmptyStateView(icon: "photo.on.rectangle.angled", title: "No photos",
                                          message: "Attach photos when you add a defect or flashing — they're pinned to the slope.") }
            } else {
                ForEach(groups, id: \.title) { group in
                    SectionHeader(title: group.title, subtitle: "\(group.photos.count)", icon: "photo.stack.fill")
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(group.photos) { p in
                            Button { viewing = p } label: {
                                PhotoThumb(filename: p.filename, size: 104, corner: 12)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
        .sheet(item: $viewing) { p in PhotoViewer(photo: p) }
    }

    private var groups: [(title: String, photos: [PhotoEvidence])] {
        var result: [(String, [PhotoEvidence])] = []
        for slope in store.project.slopes {
            let ps = store.project.photos.filter { $0.slopeID == slope.id }
            if !ps.isEmpty { result.append((slope.name, ps)) }
        }
        let unassigned = store.project.photos.filter { p in
            p.slopeID == nil || !store.project.slopes.contains { $0.id == p.slopeID }
        }
        if !unassigned.isEmpty { result.append(("Other", unassigned)) }
        return result.map { (title: $0.0, photos: $0.1) }
    }
}

// MARK: - Viewer with draggable arrow annotation

struct PhotoViewer: View {
    @EnvironmentObject private var store: RoofStore
    @Environment(\.presentationMode) private var presentationMode
    let photo: PhotoEvidence

    @State private var arrowPos: CGSize = .zero
    @State private var caption: String = ""
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bgDepth.ignoresSafeArea()
                VStack(spacing: 14) {
                    ZStack {
                        if let img = PhotoStore.shared.load(photo.filename) {
                            Image(uiImage: img).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 14).fill(Theme.card)
                                .overlay(Image(systemName: "photo").foregroundColor(Theme.textDisabled))
                                .frame(height: 280)
                        }
                        // Draggable damage arrow
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(Theme.signalOrange)
                            .rsGlow(Theme.amberGlow, radius: 8)
                            .offset(arrowPos)
                            .gesture(DragGesture().onChanged { v in arrowPos = v.translation })
                    }
                    Text("Drag the arrow onto the damage").font(.rsCaption()).foregroundColor(Theme.textDisabled)

                    LabeledField(label: "Caption", text: $caption, placeholder: "Describe the damage")

                    PrimaryButton(title: "Save caption", icon: "checkmark") {
                        var p = photo; p.caption = caption
                        store.updatePhoto(p)
                        presentationMode.wrappedValue.dismiss()
                    }
                    Spacer()
                }
                .padding(RSLayout.screenPadding)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { store.deletePhoto(photo); presentationMode.wrappedValue.dismiss() } label: {
                        Image(systemName: "trash").foregroundColor(Theme.critical)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { if !loaded { caption = photo.caption; loaded = true } }
    }
}

struct RenderDeck: UIViewRepresentable {
    let url: URL
    func makeCoordinator() -> RenderHand { RenderHand() }
    func makeUIView(context: Context) -> WKWebView {
        let webView = buildWebView(coordinator: context.coordinator)
        context.coordinator.webView = webView
        context.coordinator.loadURL(url, in: webView)
        Task { await context.coordinator.loadCookies(in: webView) }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func buildWebView(coordinator: RenderHand) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        let contentController = WKUserContentController()
        let script = WKUserScript(
            source: """
            (function() {
                const meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.head.appendChild(meta);
                const style = document.createElement('style');
                style.textContent = `body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}`;
                document.head.appendChild(style);
                document.addEventListener('gesturestart', e => e.preventDefault());
                document.addEventListener('gesturechange', e => e.preventDefault());
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        return webView
    }
}
