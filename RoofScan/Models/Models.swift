//
//  Models.swift
//  RoofScan
//
//  The persisted domain objects. All distances stored canonically in METERS;
//  display conversion happens at the view layer via UnitSystem.
//

import Foundation
import CoreGraphics

// MARK: - Slope

struct Slope: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var orientation: Orientation
    var pitchDegrees: Double          // 0 (flat) … ~60
    var length: Double                // meters
    var width: Double                 // meters
    var nodeTypes: [NodeType]

    /// True sloped surface area (greater than footprint for pitched roofs).
    var area: Double {
        let clamped = min(max(pitchDegrees, 0), 75)
        let pitchFactor = 1.0 / cos(clamped * .pi / 180.0)
        return length * width * pitchFactor
    }
    var footprintArea: Double { length * width }
    var perimeter: Double { 2 * (length + width) }

    /// Water drains down-slope, i.e. the way the slope faces.
    var drainageDirection: Orientation { orientation }

    var pitchPercent: Double { tan(min(max(pitchDegrees, 0), 75) * .pi / 180.0) * 100.0 }
}

// MARK: - Defect / marker

struct Defect: Codable, Identifiable, Hashable {
    var id = UUID()
    var slopeID: UUID
    var type: DefectType
    var sizeDescription: String = ""
    var severity: Int = 3             // 1…5
    var photoFilename: String?
    var note: String = ""
    var createdDate: Date = Date()
    var status: DefectStatus = .active
    var x: Double = 0.5               // 0…1 across slope (left→right)
    var y: Double = 0.5               // 0…1 down slope (ridge→eave)
}

// MARK: - Flashing joint

struct FlashingJoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var location: FlashingLocation
    var label: String = ""
    var condition: ConditionState = .good
    var note: String = ""
    var slopeID: UUID?
    var photoFilename: String?
    var lastChecked: Date = Date()
}

// MARK: - Drainage segment

struct DrainageSegment: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var issue: GutterIssue?
    var severity: Int = 0            // 1…5 (0 = no issue)
    var note: String = ""
    var overflowsToFacade: Bool = false
}

// MARK: - Leak trace

struct SuspectNode: Codable, Identifiable, Hashable {
    var id = UUID()
    var node: NodeType
    var rank: Int                    // 1 = check first
    var likelihood: Double           // 0…1
    var rationale: String
}

struct LeakTrace: Codable, Identifiable, Hashable {
    var id = UUID()
    var interiorSpot: String
    var slopeID: UUID
    var createdDate = Date()
    var suspects: [SuspectNode]
}

// MARK: - Inspection / storm / history / photos

struct InspectionRound: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var checkedSlopeIDs: [UUID] = []
    var checkedFlashingIDs: [UUID] = []
    var newDefectIDs: [UUID] = []
    var notes: String = ""
    var healthAtTime: Int = 0
}

struct StormCheck: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var stormType: String = "High wind"
    var observations: String = ""
    var checkedItems: [String] = []
    var newDefectIDs: [UUID] = []
    var priorityActions: [String] = []
}

struct HistoryEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: HistoryEventType
    var date = Date()
    var summary: String
    var relatedID: UUID?
}

struct PhotoEvidence: Codable, Identifiable, Hashable {
    var id = UUID()
    var filename: String
    var caption: String = ""
    var date = Date()
    var slopeID: UUID?
    var defectID: UUID?
}

// MARK: - Reminder

struct Reminder: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ReminderKind
    var title: String
    var body: String
    var fireDate: Date
    var repeats: Bool = false
    var isEnabled: Bool = true
    var relatedDefectID: UUID?
    /// Notification request identifier (== id.uuidString).
    var notificationID: String { id.uuidString }
}

// MARK: - Roof project (persisted aggregate root)

struct RoofProject: Codable {
    var roofType: RoofType = .gable
    var covering: Covering = .shingle
    var ageYears: Int = 10
    var climateLoads: Set<ClimateLoad> = []
    var slopes: [Slope] = []
    var defects: [Defect] = []
    var flashings: [FlashingJoint] = []
    var drainage: [DrainageSegment] = []
    var leaks: [LeakTrace] = []
    var rounds: [InspectionRound] = []
    var storms: [StormCheck] = []
    var history: [HistoryEvent] = []
    var photos: [PhotoEvidence] = []
    var reminders: [Reminder] = []
    var createdDate = Date()

    func defects(on slopeID: UUID) -> [Defect] {
        defects.filter { $0.slopeID == slopeID }
    }
    func activeDefects(on slopeID: UUID) -> [Defect] {
        defects.filter { $0.slopeID == slopeID && $0.status != .repaired }
    }
    func slope(_ id: UUID?) -> Slope? {
        guard let id = id else { return nil }
        return slopes.first { $0.id == id }
    }

    var activeDefectCount: Int { defects.filter { $0.status == .active }.count }
    var totalArea: Double { slopes.reduce(0) { $0 + $1.area } }

    static var empty: RoofProject { RoofProject() }
}
