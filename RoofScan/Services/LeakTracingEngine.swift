//
//  LeakTracingEngine.swift
//  RoofScan
//
//  The app's signature feature. Water always enters HIGHER up-slope than
//  the visible interior leak, so given an interior wet spot under a slope we
//  rank that slope's nodes by leak propensity + how far up-slope they sit +
//  climate amplification. Pure & deterministic.
//

import Foundation

enum LeakTracingEngine {

    /// Ranked suspect nodes to inspect, most-likely first.
    static func trace(slope: Slope, project: RoofProject) -> [SuspectNode] {
        let boosted = climateAmplifiedNodes(project)

        // Only consider nodes that exist on this slope; fall back to a sane set.
        let nodes = slope.nodeTypes.isEmpty
            ? [NodeType.ridge, .valley, .penetration, .eave]
            : slope.nodeTypes

        // Raw score: intrinsic leak weight (60%) + up-slope rank (30%) + climate (10%).
        let scored: [(node: NodeType, raw: Double)] = nodes.map { n in
            let climateBonus = boosted.contains(n) ? 1.0 : 0.0
            let raw = n.leakWeight * 0.6
                    + (Double(n.slopeRank) / 5.0) * 0.3
                    + climateBonus * 0.1
            return (n, raw)
        }

        let maxRaw = scored.map { $0.raw }.max() ?? 1
        // Stable, deterministic sort: by raw desc, then slopeRank desc, then label.
        let sorted = scored.sorted {
            if $0.raw != $1.raw { return $0.raw > $1.raw }
            if $0.node.slopeRank != $1.node.slopeRank { return $0.node.slopeRank > $1.node.slopeRank }
            return $0.node.label < $1.node.label
        }

        return sorted.enumerated().map { idx, pair in
            SuspectNode(
                node: pair.node,
                rank: idx + 1,
                likelihood: maxRaw > 0 ? pair.raw / maxRaw : 0,
                rationale: rationale(for: pair.node, slope: slope, boosted: boosted.contains(pair.node))
            )
        }
    }

    /// The inspection-corridor sentence shown above the suspect list.
    static func corridorSummary(slope: Slope) -> String {
        "Water travels down-slope, so the entry point sits ABOVE the interior stain. "
        + "Work up the \(slope.orientation.label)-facing slope from the leak toward the ridge, "
        + "checking each suspect node below in order."
    }

    // Map amplified defect types back to the nodes they live at.
    private static func climateAmplifiedNodes(_ p: RoofProject) -> Set<NodeType> {
        var set = Set<NodeType>()
        for load in p.climateLoads {
            let amp = load.amplifies
            if amp.contains(.flashingGap) { set.insert(.penetration); set.insert(.abutment) }
            if amp.contains(.ponding)    { set.insert(.valley) }
            if amp.contains(.rust)       { set.insert(.seam); set.insert(.nailLine) }
            if amp.contains(.liftedEdge) { set.insert(.ridge); set.insert(.eave) }
        }
        return set
    }

    private static func rationale(for node: NodeType, slope: Slope, boosted: Bool) -> String {
        let base: String
        switch node {
        case .penetration: base = "Pipe / chimney / skylight flashings are the #1 leak source — check the up-slope seal first."
        case .valley:      base = "Valleys concentrate runoff from two planes; debris and torn underlayment leak here."
        case .abutment:    base = "Wall junctions: step / counter-flashing pulls loose and channels water inward."
        case .seam:        base = "Panel or membrane seams open up with thermal movement."
        case .nailLine:    base = "Exposed or backed-out fasteners admit water along the nail line."
        case .ridge:       base = "Ridge caps lift in wind — inspect from the top down."
        case .eave:        base = "Eaves are lowest; only suspect them if ice-damming or back-up is possible."
        }
        let boost = boosted ? " Active climate load raises this node's priority." : ""
        return base + boost
    }
}
