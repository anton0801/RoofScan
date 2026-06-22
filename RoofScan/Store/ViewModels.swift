//
//  ViewModels.swift
//  RoofScan
//
//  Transient per-screen ViewModels for the stateful calculators/wizards.
//  Screens that are pure CRUD read RoofStore directly instead.
//

import SwiftUI

// MARK: - Onboarding wizard

final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    @Published var roofType: RoofType = .gable
    @Published var covering: Covering = .shingle
    @Published var age: Double = 10
    @Published var climate: Set<ClimateLoad> = []

    let lastStep = 3

    func next() { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { if step < lastStep { step += 1 } } }
    func back() { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { if step > 0 { step -= 1 } } }
    func go(to s: Int) { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step = max(0, min(lastStep, s)) } }

    func toggleClimate(_ c: ClimateLoad) {
        if climate.contains(c) { climate.remove(c) } else { climate.insert(c) }
    }

    func commit(to store: RoofStore) {
        store.applyOnboarding(roofType: roofType, covering: covering,
                              age: Int(age.rounded()), climate: climate)
    }
}

// MARK: - Leak trace

final class LeakTraceViewModel: ObservableObject {
    @Published var interiorSpot = ""
    @Published var selectedSlopeID: UUID?
    @Published var suspects: [SuspectNode] = []
    @Published var corridor = ""
    @Published var didRun = false

    var canRun: Bool { selectedSlopeID != nil && !interiorSpot.trimmingCharacters(in: .whitespaces).isEmpty }

    func run(project: RoofProject) {
        guard let id = selectedSlopeID, let slope = project.slope(id) else { return }
        suspects = LeakTracingEngine.trace(slope: slope, project: project)
        corridor = LeakTracingEngine.corridorSummary(slope: slope)
        didRun = true
    }

    func save(to store: RoofStore) {
        guard let id = selectedSlopeID, !suspects.isEmpty else { return }
        let trace = LeakTrace(interiorSpot: interiorSpot.trimmingCharacters(in: .whitespaces),
                              slopeID: id, suspects: suspects)
        store.saveLeakTrace(trace)
    }

    func reset() {
        interiorSpot = ""; selectedSlopeID = nil; suspects = []; corridor = ""; didRun = false
    }
}

// MARK: - Material estimate

final class MaterialEstimateViewModel: ObservableObject {
    @Published var selectedSlopeIDs: Set<UUID> = []
    @Published var wastePercent: Double = 10
    @Published var bill: MaterialBill?

    func toggle(_ id: UUID) {
        if selectedSlopeIDs.contains(id) { selectedSlopeIDs.remove(id) } else { selectedSlopeIDs.insert(id) }
        bill = nil
    }
    func selectAll(_ project: RoofProject) {
        selectedSlopeIDs = Set(project.slopes.map { $0.id }); bill = nil
    }

    func totalArea(_ project: RoofProject) -> Double {
        project.slopes.filter { selectedSlopeIDs.contains($0.id) }.reduce(0) { $0 + $1.area }
    }

    func compute(_ project: RoofProject) {
        let area = totalArea(project)
        var opts = MaterialEngine.Options()
        opts.wasteFactor = 1 + wastePercent / 100
        bill = MaterialEngine.bill(covering: project.covering, areaM2: area, opts: opts)
    }
}

// MARK: - Repair cost

final class RepairCostViewModel: ObservableObject {
    @Published var estimate: RepairEstimate?

    func compute(project: RoofProject, rate: Double, currency: String) {
        estimate = RepairCostEngine.estimate(defects: project.defects, hourlyRate: rate, currency: currency)
    }
}

// MARK: - Reports

final class ReportsViewModel: ObservableObject {
    @Published var includePhotos = true
    @Published var generatedURL: URL?
    @Published var isSharing = false
    @Published var generating = false

    func generate(project: RoofProject, settings: AppSettings) {
        generating = true
        let cfg = PDFReportService.ReportSettings(currency: settings.currency,
                                                  hourlyRate: settings.hourlyRate,
                                                  unitSystem: settings.unitSystem,
                                                  includePhotos: includePhotos)
        DispatchQueue.global(qos: .userInitiated).async {
            let url = PDFReportService.generate(project: project, settings: cfg)
            DispatchQueue.main.async {
                self.generatedURL = url
                self.generating = false
                self.isSharing = url != nil
            }
        }
    }
}
