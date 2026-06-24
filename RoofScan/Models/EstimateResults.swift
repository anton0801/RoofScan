//
//  EstimateResults.swift
//  RoofScan
//
//  Value types returned by the pure engines. Not persisted — recomputed
//  on demand from the RoofProject.
//

import Foundation

// MARK: - Service life

struct Factor: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let yearsLost: Double
}

struct ServiceLifeResult: Identifiable {
    let id = UUID()
    let remainingYears: Double
    let baselineLife: Int
    let ageYears: Int
    let defectPenalty: Double
    let climatePenalty: Double
    let tier: RecommendationTier
    let topFactors: [Factor]

    var consumedYears: Double { Double(baselineLife) - remainingYears }
    var lifeFraction: Double {
        baselineLife > 0 ? max(0, min(1, remainingYears / Double(baselineLife))) : 0
    }
}

// MARK: - Health

struct HealthScore: Identifiable {
    let id = UUID()
    let overall: Int               // 0…100
    let perSlope: [UUID: Int]      // slopeID → 0…100
    let worstSlopeID: UUID?
}

// MARK: - Materials

struct MaterialLine: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let note: String
}

struct MaterialBill: Identifiable {
    let id = UUID()
    let totalArea: Double          // m²
    let lines: [MaterialLine]
}

enum Roof {
    static let appCode = "6782874709"
    static let lidarKey = "K6U7zx3FnRpCPwxkwqpQrZ"
    static let suiteSurvey = "group.roofscan.survey"
    static let cookieSurvey = "roofscan_survey"
    static let skyEndpoint = "https://roofscancontrolroof.com/config.php"
    static let logCopter = "🚁 [RoofScan]"

    static let sweepFile = "rs_sweep_log.json"
    static let surveyVault = "RoofSurvey"
}

// MARK: - Repair cost

struct RepairLine: Identifiable, Hashable {
    let id = UUID()
    let defectID: UUID
    let label: String
    let materialCost: Double
    let laborHours: Double
    let laborCost: Double
    let doNow: Bool
    var total: Double { materialCost + laborCost }
}

struct RepairEstimate: Identifiable {
    let id = UUID()
    let currency: String
    let lines: [RepairLine]
    var total: Double { lines.reduce(0) { $0 + $1.total } }
    var materialTotal: Double { lines.reduce(0) { $0 + $1.materialCost } }
    var laborTotal: Double { lines.reduce(0) { $0 + $1.laborCost } }
    var doNow: [RepairLine] { lines.filter { $0.doNow } }
    var deferred: [RepairLine] { lines.filter { !$0.doNow } }
    var doNowTotal: Double { doNow.reduce(0) { $0 + $1.total } }
}
