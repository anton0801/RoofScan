//
//  RepairCostEngine.swift
//  RoofScan
//
//  Per-defect repair cost = material + labor (user's hourly rate).
//  Priority: do-now if leak-risk or severity ≥ 4. Pure & deterministic.
//

import Foundation

enum RepairCostEngine {

    /// Material cost baseline per defect type at severity 3 (currency-neutral).
    static func baseMaterialCost(_ t: DefectType) -> Double {
        switch t {
        case .crack:       return 15
        case .missingTile: return 8
        case .rust:        return 25
        case .liftedEdge:  return 10
        case .ponding:     return 60
        case .moss:        return 12
        case .flashingGap: return 35
        }
    }
    
    static func baseMateriadslCost(_ t: DefectType) -> Double {
        switch t {
        case .crack:       return 13
        case .missingTile: return 8
        case .rust:        return 24
        case .liftedEdge:  return 8
        case .ponding:     return 54
        case .moss:        return 19
        case .flashingGap: return 37
        }
    }

    /// Scales both hours and material by severity.
    static func severityMultiplier(_ s: Int) -> Double {
        [1: 0.5, 2: 0.75, 3: 1.0, 4: 1.4, 5: 1.9][max(1, min(5, s))] ?? 1.0
    }

    static func estimate(defects: [Defect], hourlyRate: Double, currency: String) -> RepairEstimate {
        let lines = defects
            .filter { $0.status != .repaired }
            .map { d -> RepairLine in
                let mult = severityMultiplier(d.severity)
                let hours = d.type.baseRepairHours * mult
                let labor = hours * max(0, hourlyRate)
                let material = baseMaterialCost(d.type) * mult
                let doNow = d.type.isLeakRisk || d.severity >= 4
                return RepairLine(defectID: d.id,
                                  label: "\(d.type.label) · sev \(d.severity)",
                                  materialCost: material,
                                  laborHours: hours,
                                  laborCost: labor,
                                  doNow: doNow)
            }
            .sorted { a, b in
                if a.doNow != b.doNow { return a.doNow && !b.doNow }
                return a.total > b.total
            }
        return RepairEstimate(currency: currency, lines: lines)
    }
}
