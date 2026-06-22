//
//  RoofStore.swift
//  RoofScan
//
//  Single source of truth (@EnvironmentObject). Holds the RoofProject,
//  exposes CRUD intents (each logs a HistoryEvent), debounced autosave,
//  and derived engine results.
//

import SwiftUI
import Combine

final class RoofStore: ObservableObject {

    @Published var project: RoofProject { didSet { scheduleSave() } }

    private var saveWorkItem: DispatchWorkItem?

    init(project: RoofProject? = nil) {
        self.project = project ?? PersistenceService.shared.load()
    }

    // MARK: - Derived results

    var health: HealthScore { ServiceLifeEngine.health(project: project) }
    var serviceLife: ServiceLifeResult { ServiceLifeEngine.estimate(project: project) }

    var worstSlope: Slope? {
        guard let id = health.worstSlopeID else { return project.slopes.first }
        return project.slopes.first { $0.id == id }
    }

    // MARK: - Onboarding commit

    /// Configure roof from onboarding choices and seed starter slopes.
    func applyOnboarding(roofType: RoofType, covering: Covering, age: Int, climate: Set<ClimateLoad>) {
        project.roofType = roofType
        project.covering = covering
        project.ageYears = age
        project.climateLoads = climate
        if project.slopes.isEmpty {
            project.slopes = Self.seedSlopes(for: roofType)
        }
        log(.slopeAdded, "Roof configured: \(roofType.label), \(covering.label), \(age) yr")
        saveNow()
    }

    static func seedSlopes(for type: RoofType) -> [Slope] {
        let nodes = type.typicalNodes
        func slope(_ name: String, _ o: Orientation, pitch: Double, l: Double, w: Double) -> Slope {
            Slope(name: name, orientation: o, pitchDegrees: pitch, length: l, width: w, nodeTypes: nodes)
        }
        switch type {
        case .gable:
            return [slope("North slope", .north, pitch: 35, l: 8, w: 5),
                    slope("South slope", .south, pitch: 35, l: 8, w: 5)]
        case .hip:
            return [slope("North slope", .north, pitch: 30, l: 8, w: 4),
                    slope("South slope", .south, pitch: 30, l: 8, w: 4),
                    slope("East slope", .east, pitch: 30, l: 5, w: 4),
                    slope("West slope", .west, pitch: 30, l: 5, w: 4)]
        case .flat:
            return [slope("Main deck", .south, pitch: 3, l: 9, w: 7)]
        case .mono:
            return [slope("Single slope", .south, pitch: 15, l: 9, w: 6)]
        case .complex:
            return [slope("North main", .north, pitch: 35, l: 8, w: 5),
                    slope("South main", .south, pitch: 35, l: 8, w: 5),
                    slope("East dormer", .east, pitch: 30, l: 4, w: 3),
                    slope("West wing", .west, pitch: 25, l: 6, w: 4)]
        }
    }

    // MARK: - Slopes

    func addSlope(_ s: Slope) {
        project.slopes.append(s)
        log(.slopeAdded, "Added slope “\(s.name)”", related: s.id)
    }
    func updateSlope(_ s: Slope) {
        guard let i = project.slopes.firstIndex(where: { $0.id == s.id }) else { return }
        project.slopes[i] = s
    }
    func deleteSlope(_ s: Slope) {
        project.slopes.removeAll { $0.id == s.id }
        for d in project.defects(on: s.id) { PhotoStore.shared.delete(d.photoFilename) }
        project.defects.removeAll { $0.slopeID == s.id }
        project.leaks.removeAll { $0.slopeID == s.id }
    }

    // MARK: - Defects

    func addDefect(_ d: Defect) {
        project.defects.append(d)
        log(.defectAdded, "\(d.type.label) marked on \(slopeName(d.slopeID))", related: d.id)
    }
    func updateDefect(_ d: Defect) {
        guard let i = project.defects.firstIndex(where: { $0.id == d.id }) else { return }
        let old = project.defects[i]
        project.defects[i] = d
        if d.severity > old.severity {
            log(.defectGrew, "\(d.type.label) grew to severity \(d.severity)", related: d.id)
        }
    }
    func deleteDefect(_ d: Defect) {
        PhotoStore.shared.delete(d.photoFilename)
        project.defects.removeAll { $0.id == d.id }
        project.photos.removeAll { $0.defectID == d.id }
    }
    func setDefectStatus(_ id: UUID, _ status: DefectStatus) {
        guard let i = project.defects.firstIndex(where: { $0.id == id }) else { return }
        project.defects[i].status = status
        if status == .repaired {
            log(.defectRepaired, "Repaired \(project.defects[i].type.label)", related: id)
        }
    }

    // MARK: - Flashings

    func addFlashing(_ f: FlashingJoint) { project.flashings.append(f) }
    func updateFlashing(_ f: FlashingJoint) {
        guard let i = project.flashings.firstIndex(where: { $0.id == f.id }) else { return }
        project.flashings[i] = f
    }
    func deleteFlashing(_ f: FlashingJoint) {
        PhotoStore.shared.delete(f.photoFilename)
        project.flashings.removeAll { $0.id == f.id }
    }

    // MARK: - Drainage

    func addDrainage(_ g: DrainageSegment) { project.drainage.append(g) }
    func updateDrainage(_ g: DrainageSegment) {
        guard let i = project.drainage.firstIndex(where: { $0.id == g.id }) else { return }
        project.drainage[i] = g
    }
    func deleteDrainage(_ g: DrainageSegment) { project.drainage.removeAll { $0.id == g.id } }

    // MARK: - Leak traces

    func saveLeakTrace(_ t: LeakTrace) {
        project.leaks.insert(t, at: 0)
        log(.leakTraced, "Traced leak at “\(t.interiorSpot)”", related: t.id)
    }
    func deleteLeak(_ t: LeakTrace) { project.leaks.removeAll { $0.id == t.id } }

    // MARK: - Inspections / storms

    func addRound(_ r: InspectionRound) {
        var round = r
        round.healthAtTime = health.overall
        project.rounds.insert(round, at: 0)
        log(.inspection, "Inspection round — \(round.checkedSlopeIDs.count) slopes, health \(round.healthAtTime)%")
    }
    func addStorm(_ s: StormCheck) {
        project.storms.insert(s, at: 0)
        log(.storm, "Storm check (\(s.stormType)) — \(s.checkedItems.count) items reviewed")
    }

    // MARK: - Photos

    func addPhoto(_ p: PhotoEvidence) { project.photos.insert(p, at: 0) }
    func updatePhoto(_ p: PhotoEvidence) {
        guard let i = project.photos.firstIndex(where: { $0.id == p.id }) else { return }
        project.photos[i] = p
    }
    func deletePhoto(_ p: PhotoEvidence) {
        PhotoStore.shared.delete(p.filename)
        project.photos.removeAll { $0.id == p.id }
    }

    // MARK: - Reminders

    func setReminder(_ r: Reminder) {
        if let i = project.reminders.firstIndex(where: { $0.id == r.id }) {
            project.reminders[i] = r
        } else {
            project.reminders.append(r)
            log(.reminderSet, "Reminder “\(r.title)” set", related: r.id)
        }
        NotificationService.shared.schedule(r)
    }
    func toggleReminder(_ r: Reminder, on: Bool) {
        guard let i = project.reminders.firstIndex(where: { $0.id == r.id }) else { return }
        project.reminders[i].isEnabled = on
        NotificationService.shared.schedule(project.reminders[i])
    }
    func deleteReminder(_ r: Reminder) {
        NotificationService.shared.cancel(id: r.notificationID)
        project.reminders.removeAll { $0.id == r.id }
    }

    func noteEstimateRun(_ what: String) { log(.estimateRun, what) }

    /// Pre-populate seasonal & gutter reminders (disabled until the user opts in).
    func seedDefaultReminders() {
        guard project.reminders.isEmpty else { return }
        let spring = Self.nextDate(month: 3, day: 15, hour: 9)
        let fall = Self.nextDate(month: 10, day: 1, hour: 9)
        let gutter = Self.nextDate(month: 11, day: 1, hour: 9)
        let seeds: [(ReminderKind, Date)] = [
            (.seasonalSpring, spring), (.seasonalFall, fall), (.gutterCleaning, gutter)
        ]
        for (kind, date) in seeds {
            project.reminders.append(
                Reminder(kind: kind, title: kind.label, body: kind.defaultBody,
                         fireDate: date, repeats: true, isEnabled: false)
            )
        }
    }

    /// Next future occurrence of a month/day/hour.
    static func nextDate(month: Int, day: Int, hour: Int) -> Date {
        var comps = DateComponents()
        comps.month = month; comps.day = day; comps.hour = hour; comps.minute = 0
        let cal = Calendar.current
        if let d = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) {
            return d
        }
        return Date().addingTimeInterval(86400 * 30)
    }

    // MARK: - Reset & maintenance

    func resetAll() {
        for r in project.reminders { NotificationService.shared.cancel(id: r.notificationID) }
        PhotoStore.shared.garbageCollect(referenced: [])
        project = .empty
        saveNow()
    }

    func garbageCollectPhotos() {
        var referenced = Set(project.photos.map { $0.filename })
        referenced.formUnion(project.defects.compactMap { $0.photoFilename })
        referenced.formUnion(project.flashings.compactMap { $0.photoFilename })
        PhotoStore.shared.garbageCollect(referenced: referenced)
    }

    // MARK: - Helpers

    func slopeName(_ id: UUID) -> String {
        project.slopes.first { $0.id == id }?.name ?? "roof"
    }

    private func log(_ type: HistoryEventType, _ summary: String, related: UUID? = nil) {
        project.history.insert(HistoryEvent(type: type, summary: summary, relatedID: related), at: 0)
        if project.history.count > 300 { project.history.removeLast(project.history.count - 300) }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = project
        let work = DispatchWorkItem { PersistenceService.shared.save(snapshot) }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        PersistenceService.shared.save(project)
    }
}
