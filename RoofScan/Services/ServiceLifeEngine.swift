//
//  ServiceLifeEngine.swift
//  RoofScan
//
//  Remaining-life estimate and roof health %.  Pure & deterministic.
//
//    remaining = baselineLife(covering) - age - defectPenalty - climatePenalty
//

import Foundation

enum ServiceLifeEngine {

    // Severity → years-of-life lost per defect.
    static func severityWeight(_ s: Int) -> Double {
        [1: 0.3, 2: 0.7, 3: 1.2, 4: 2.0, 5: 3.0][max(1, min(5, s))] ?? 1.2
    }

    static func estimate(project p: RoofProject) -> ServiceLifeResult {
        let base = Double(p.covering.baselineLife)
        let age = Double(p.ageYears)

        let activeDefects = p.defects.filter { $0.status != .repaired }
        let defectPenalty = activeDefects.reduce(0.0) { acc, d in
            acc + severityWeight(d.severity) * (d.type.isLeakRisk ? 1.5 : 1.0)
        }
        let climatePenalty = p.climateLoads.reduce(0.0) { $0 + $1.lifePenalty }

        let remaining = max(0, base - age - defectPenalty - climatePenalty)
        let tier = recommendation(remaining: remaining, base: base,
                                  hasCriticalLeak: hasCriticalLeak(p))

        var factors: [Factor] = [
            Factor(label: "Age — \(p.ageYears) yr in service", yearsLost: age),
            Factor(label: "\(activeDefects.count) active defect\(activeDefects.count == 1 ? "" : "s")",
                   yearsLost: defectPenalty),
            Factor(label: "Climate load (\(p.climateLoads.count))", yearsLost: climatePenalty)
        ]
        factors = factors.filter { $0.yearsLost > 0.01 }.sorted { $0.yearsLost > $1.yearsLost }

        return ServiceLifeResult(
            remainingYears: remaining,
            baselineLife: p.covering.baselineLife,
            ageYears: p.ageYears,
            defectPenalty: defectPenalty,
            climatePenalty: climatePenalty,
            tier: tier,
            topFactors: factors
        )
    }

    private static func hasCriticalLeak(_ p: RoofProject) -> Bool {
        p.defects.contains { $0.status != .repaired && $0.type.isLeakRisk && $0.severity >= 4 }
    }

    private static func recommendation(remaining: Double, base: Double,
                                       hasCriticalLeak: Bool) -> RecommendationTier {
        if hasCriticalLeak && remaining < base * 0.25 { return .replaceNow }
        let ratio = base > 0 ? remaining / base : 0
        switch ratio {
        case ..<0.10: return .replaceNow
        case ..<0.30: return .planReplacement
        case ..<0.60: return .repair
        default:      return .monitor
        }
    }

    // MARK: - Health %

    static func health(project p: RoofProject) -> HealthScore {
        let est = estimate(project: p)
        let base = max(1.0, Double(p.covering.baselineLife))
        var score = (est.remainingYears / base) * 100.0

        let defectDrag = min(40.0, p.defects.filter { $0.status == .active }
            .reduce(0.0) { $0 + Double($1.severity) * 2.0 })
        let flashDrag = min(15.0, Double(p.flashings.filter { $0.condition == .failed }.count) * 5.0)
        let gutterDrag = min(15.0, p.drainage.reduce(0.0) { $0 + Double($1.severity) })

        score = max(0, min(100, score - defectDrag - flashDrag - gutterDrag))

        var perSlope: [UUID: Int] = [:]
        for s in p.slopes {
            let worst = p.activeDefects(on: s.id).map { $0.severity }.max() ?? 0
            perSlope[s.id] = max(0, 100 - worst * 18)
        }
        let worstSlope = perSlope.min { $0.value < $1.value }?.key

        return HealthScore(overall: Int(score.rounded()),
                           perSlope: perSlope,
                           worstSlopeID: worstSlope)
    }
}
