//
//  Enums.swift
//  RoofScan
//
//  Every domain enum, each carrying the constants the engines consume
//  (baseline life, leak weights, repair hours, climate penalties, …).
//

import SwiftUI

// MARK: - Roof type

enum RoofType: String, Codable, CaseIterable, Identifiable {
    case gable, hip, flat, mono, complex
    var id: String { rawValue }

    var label: String {
        switch self {
        case .gable:   return "Gable"
        case .hip:     return "Hip"
        case .flat:    return "Flat"
        case .mono:    return "Mono-pitch"
        case .complex: return "Complex"
        }
    }

    var detail: String {
        switch self {
        case .gable:   return "Two slopes meeting at a ridge"
        case .hip:     return "Four sloping sides, no gable ends"
        case .flat:    return "Near-level deck with internal drainage"
        case .mono:    return "Single slope, one high & one low edge"
        case .complex: return "Mixed planes, valleys and dormers"
        }
    }

    var icon: String {
        switch self {
        case .gable:   return "house.fill"
        case .hip:     return "triangle.fill"
        case .flat:    return "rectangle.fill"
        case .mono:    return "line.diagonal"
        case .complex: return "square.stack.3d.up.fill"
        }
    }

    /// Node types this geometry typically presents — used to seed new slopes.
    var typicalNodes: [NodeType] {
        switch self {
        case .gable:   return [.ridge, .eave, .abutment]
        case .hip:     return [.ridge, .valley, .eave]
        case .flat:    return [.seam, .penetration, .eave]
        case .mono:    return [.ridge, .eave, .abutment]
        case .complex: return [.ridge, .valley, .abutment, .penetration, .eave]
        }
    }

    /// How many starter slopes to suggest for the layout.
    var suggestedSlopeCount: Int {
        switch self {
        case .gable: return 2
        case .hip:   return 4
        case .flat:  return 1
        case .mono:  return 1
        case .complex: return 4
        }
    }
}

// MARK: - Covering

enum Covering: String, Codable, CaseIterable, Identifiable {
    case shingle, metal, tile, slate, bitumen, membrane
    var id: String { rawValue }

    var label: String {
        switch self {
        case .shingle:  return "Shingle"
        case .metal:    return "Metal"
        case .tile:     return "Tile"
        case .slate:    return "Slate"
        case .bitumen:  return "Bitumen"
        case .membrane: return "Membrane"
        }
    }

    var icon: String {
        switch self {
        case .shingle:  return "square.grid.3x3.fill"
        case .metal:    return "rectangle.split.3x1.fill"
        case .tile:     return "circle.grid.3x3.fill"
        case .slate:    return "square.stack.fill"
        case .bitumen:  return "drop.fill"
        case .membrane: return "rectangle.fill"
        }
    }

    /// Baseline expected service life in years (manufacturer-typical midpoints).
    var baselineLife: Int {
        switch self {
        case .shingle:  return 22
        case .metal:    return 45
        case .tile:     return 55
        case .slate:    return 90
        case .bitumen:  return 18
        case .membrane: return 25
        }
    }

    /// Defects most commonly seen on this covering (shown as hints).
    var commonDefects: [DefectType] {
        switch self {
        case .shingle:  return [.liftedEdge, .crack, .moss]
        case .metal:    return [.rust, .flashingGap, .liftedEdge]
        case .tile:     return [.missingTile, .crack, .moss]
        case .slate:    return [.crack, .missingTile, .flashingGap]
        case .bitumen:  return [.crack, .ponding, .liftedEdge]
        case .membrane: return [.ponding, .flashingGap, .crack]
        }
    }
}

// MARK: - Climate load (multi-select)

enum ClimateLoad: String, Codable, CaseIterable, Identifiable {
    case snow, heavyRain, heat, coastalSalt
    var id: String { rawValue }

    var label: String {
        switch self {
        case .snow:        return "Snow load"
        case .heavyRain:   return "Heavy rain"
        case .heat:        return "Intense heat"
        case .coastalSalt: return "Coastal salt"
        }
    }

    var icon: String {
        switch self {
        case .snow:        return "snowflake"
        case .heavyRain:   return "cloud.rain.fill"
        case .heat:        return "sun.max.fill"
        case .coastalSalt: return "water.waves"
        }
    }

    /// Years of life penalty for each active load.
    var lifePenalty: Double {
        switch self {
        case .snow:        return 2.0
        case .heavyRain:   return 2.5
        case .heat:        return 1.5
        case .coastalSalt: return 3.0
        }
    }

    /// Defect types this load amplifies.
    var amplifies: Set<DefectType> {
        switch self {
        case .snow:        return [.liftedEdge, .flashingGap, .ponding]
        case .heavyRain:   return [.ponding, .flashingGap, .rust]
        case .heat:        return [.crack, .liftedEdge]
        case .coastalSalt: return [.rust, .flashingGap]
        }
    }

    /// Reminder cadence boost — more aggressive climates inspect more often.
    var inspectionMonths: Int {
        switch self {
        case .snow:        return 6
        case .heavyRain:   return 4
        case .heat:        return 6
        case .coastalSalt: return 4
        }
    }
}

// MARK: - Orientation

enum Orientation: String, Codable, CaseIterable, Identifiable {
    case north = "N", south = "S", east = "E", west = "W"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .north: return "North"
        case .south: return "South"
        case .east:  return "East"
        case .west:  return "West"
        }
    }

    /// Unit azimuth in plan space (x = east, y = north).
    var azimuth: CGVector {
        switch self {
        case .north: return CGVector(dx: 0,  dy: 1)
        case .south: return CGVector(dx: 0,  dy: -1)
        case .east:  return CGVector(dx: 1,  dy: 0)
        case .west:  return CGVector(dx: -1, dy: 0)
        }
    }
}

// MARK: - Node types

enum NodeType: String, Codable, CaseIterable, Identifiable {
    case eave, ridge, valley, abutment, penetration, seam, nailLine
    var id: String { rawValue }

    var label: String {
        switch self {
        case .eave:        return "Eave"
        case .ridge:       return "Ridge"
        case .valley:      return "Valley"
        case .abutment:    return "Wall abutment"
        case .penetration: return "Penetration"
        case .seam:        return "Seam"
        case .nailLine:    return "Nail line"
        }
    }

    var icon: String {
        switch self {
        case .eave:        return "arrow.down.to.line"
        case .ridge:       return "triangle"
        case .valley:      return "arrow.triangle.merge"
        case .abutment:    return "square.righthalf.filled"
        case .penetration: return "smoke.fill"
        case .seam:        return "rectangle.split.2x1"
        case .nailLine:    return "pin.fill"
        }
    }

    /// Intrinsic leak propensity (0..1) — penetrations & valleys leak most.
    var leakWeight: Double {
        switch self {
        case .penetration: return 1.00
        case .valley:      return 0.90
        case .abutment:    return 0.80
        case .seam:        return 0.65
        case .nailLine:    return 0.50
        case .ridge:       return 0.40
        case .eave:        return 0.20
        }
    }

    /// How high up-slope the node sits (5 = ridge top, 1 = eave bottom).
    var slopeRank: Int {
        switch self {
        case .ridge:       return 5
        case .penetration: return 4
        case .abutment:    return 4
        case .valley:      return 3
        case .seam:        return 2
        case .nailLine:    return 2
        case .eave:        return 1
        }
    }
}

// MARK: - Defect type

enum DefectType: String, Codable, CaseIterable, Identifiable {
    case crack, missingTile, rust, liftedEdge, ponding, moss, flashingGap
    var id: String { rawValue }

    var label: String {
        switch self {
        case .crack:       return "Crack"
        case .missingTile: return "Missing tile"
        case .rust:        return "Rust"
        case .liftedEdge:  return "Lifted edge"
        case .ponding:     return "Ponding water"
        case .moss:        return "Moss / growth"
        case .flashingGap: return "Flashing gap"
        }
    }

    var icon: String {
        switch self {
        case .crack:       return "bolt.fill"
        case .missingTile: return "square.dashed"
        case .rust:        return "circle.hexagongrid.fill"
        case .liftedEdge:  return "wind"
        case .ponding:     return "drop.triangle.fill"
        case .moss:        return "leaf.fill"
        case .flashingGap: return "rectangle.badge.xmark"
        }
    }

    /// Base labor hours to repair one occurrence at severity 3.
    var baseRepairHours: Double {
        switch self {
        case .crack:       return 1.0
        case .missingTile: return 0.6
        case .rust:        return 1.5
        case .liftedEdge:  return 0.8
        case .ponding:     return 3.0
        case .moss:        return 1.2
        case .flashingGap: return 1.8
        }
    }

    /// Direct water-ingress risk — raises priority & health penalty.
    var isLeakRisk: Bool {
        switch self {
        case .crack, .ponding, .flashingGap, .missingTile, .liftedEdge: return true
        case .rust, .moss: return false
        }
    }
}

// MARK: - Defect status

enum DefectStatus: String, Codable, CaseIterable, Identifiable {
    case active, inProgress, repaired
    var id: String { rawValue }
    var label: String {
        switch self {
        case .active:     return "Active"
        case .inProgress: return "In progress"
        case .repaired:   return "Repaired"
        }
    }
}

// MARK: - Flashing

enum FlashingLocation: String, Codable, CaseIterable, Identifiable {
    case pipe, chimney, wall, skylight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pipe:     return "Pipe / vent"
        case .chimney:  return "Chimney"
        case .wall:     return "Wall junction"
        case .skylight: return "Skylight"
        }
    }
    var icon: String {
        switch self {
        case .pipe:     return "pipe.and.drop.fill"
        case .chimney:  return "house.lodge.fill"
        case .wall:     return "building.2.fill"
        case .skylight: return "window.ceiling"
        }
    }
}

enum ConditionState: String, Codable, CaseIterable, Identifiable {
    case good, worn, cracked, failed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .good:    return "Good"
        case .worn:    return "Worn"
        case .cracked: return "Cracked"
        case .failed:  return "Failed"
        }
    }
    /// 3 (good) … 0 (failed) — used in health.
    var score: Int {
        switch self {
        case .good: return 3
        case .worn: return 2
        case .cracked: return 1
        case .failed: return 0
        }
    }
}

// MARK: - Drainage

enum GutterIssue: String, Codable, CaseIterable, Identifiable {
    case clog, sag, slope, overflow
    var id: String { rawValue }
    var label: String {
        switch self {
        case .clog:     return "Clogged"
        case .sag:      return "Sagging"
        case .slope:    return "Wrong slope"
        case .overflow: return "Overflowing"
        }
    }
    var icon: String {
        switch self {
        case .clog:     return "leaf.fill"
        case .sag:      return "arrow.down.right"
        case .slope:    return "angle"
        case .overflow: return "drop.fill"
        }
    }
}

// MARK: - History & reminders

enum HistoryEventType: String, Codable, CaseIterable, Identifiable {
    case defectAdded, defectGrew, defectRepaired, inspection, storm
    case reminderSet, slopeAdded, leakTraced, estimateRun
    var id: String { rawValue }
    var label: String {
        switch self {
        case .defectAdded:    return "Marker added"
        case .defectGrew:     return "Defect grew"
        case .defectRepaired: return "Repaired"
        case .inspection:     return "Inspected"
        case .storm:          return "Storm checked"
        case .reminderSet:    return "Reminder set"
        case .slopeAdded:     return "Slope added"
        case .leakTraced:     return "Leak traced"
        case .estimateRun:    return "Estimate run"
        }
    }
    var icon: String {
        switch self {
        case .defectAdded:    return "plus.circle.fill"
        case .defectGrew:     return "arrow.up.right.circle.fill"
        case .defectRepaired: return "checkmark.seal.fill"
        case .inspection:     return "checklist"
        case .storm:          return "cloud.bolt.rain.fill"
        case .reminderSet:    return "bell.fill"
        case .slopeAdded:     return "square.on.square"
        case .leakTraced:     return "drop.degreesign.fill"
        case .estimateRun:    return "function"
        }
    }
    var color: Color {
        switch self {
        case .defectAdded, .defectGrew, .storm: return Theme.signalOrange
        case .defectRepaired, .inspection:      return Theme.ok
        case .reminderSet:                      return Theme.amber
        default:                                return Theme.primary
        }
    }
}

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case seasonalSpring, seasonalFall, postStorm, gutterCleaning, criticalRecheck
    var id: String { rawValue }
    var label: String {
        switch self {
        case .seasonalSpring:  return "Spring inspection"
        case .seasonalFall:    return "Fall inspection"
        case .postStorm:       return "Post-storm check"
        case .gutterCleaning:  return "Gutter cleaning"
        case .criticalRecheck: return "Re-check critical defect"
        }
    }
    var icon: String {
        switch self {
        case .seasonalSpring:  return "leaf.fill"
        case .seasonalFall:    return "wind"
        case .postStorm:       return "cloud.bolt.rain.fill"
        case .gutterCleaning:  return "drop.fill"
        case .criticalRecheck: return "exclamationmark.triangle.fill"
        }
    }
    var defaultBody: String {
        switch self {
        case .seasonalSpring:  return "Walk every slope after winter — check lifted edges, cracked seals and blocked valleys."
        case .seasonalFall:    return "Clear leaves and inspect flashings before the wet season."
        case .postStorm:       return "Inspect vulnerable nodes for wind-lifted and displaced elements."
        case .gutterCleaning:  return "Clear gutters and downpipes so water leaves the roof cleanly."
        case .criticalRecheck: return "A critical defect is due for re-inspection — confirm it has not grown."
        }
    }
}

// MARK: - Recommendation tier

enum RecommendationTier: Int, Codable, CaseIterable {
    case monitor = 0, repair, planReplacement, replaceNow
    var label: String {
        switch self {
        case .monitor:         return "Monitor"
        case .repair:          return "Repair soon"
        case .planReplacement: return "Plan replacement"
        case .replaceNow:      return "Replace now"
        }
    }
    var color: Color {
        switch self {
        case .monitor:         return Theme.ok
        case .repair:          return Theme.amber
        case .planReplacement: return Theme.signalOrange
        case .replaceNow:      return Theme.critical
        }
    }
    var icon: String {
        switch self {
        case .monitor:         return "checkmark.circle.fill"
        case .repair:          return "wrench.adjustable.fill"
        case .planReplacement: return "calendar.badge.exclamationmark"
        case .replaceNow:      return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Settings enums

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var label: String { self == .metric ? "Metric (m, m²)" : "Imperial (ft, ft²)" }
    var lengthUnit: String { self == .metric ? "m" : "ft" }
    var areaUnit: String { self == .metric ? "m²" : "ft²" }
    /// Convert canonical meters to the display unit.
    var lengthFactor: Double { self == .metric ? 1.0 : 3.28084 }
    var areaFactor: Double { self == .metric ? 1.0 : 10.7639 }
}

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
