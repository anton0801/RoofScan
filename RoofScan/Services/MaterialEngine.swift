//
//  MaterialEngine.swift
//  RoofScan
//
//  Repair material take-off from covering type + area to repair.
//  Areas are passed in canonical m². Coverage constants are explicit.
//

import Foundation

enum MaterialEngine {

    struct Options {
        var wasteFactor: Double = 1.10   // +10% waste/offcuts
    }

    static func bill(covering: Covering, areaM2: Double, opts: Options = Options()) -> MaterialBill {
        let net = max(0, areaM2)
        let area = net * opts.wasteFactor
        var lines: [MaterialLine] = []

        switch covering {
        case .shingle:
            lines.append(MaterialLine(name: "Shingle bundles", quantity: ceil(area / 3.1),
                                      unit: "bundles", note: "≈3.1 m² per bundle"))
            lines.append(MaterialLine(name: "Roofing nails", quantity: ceil(area * 14),
                                      unit: "pcs", note: "≈14 nails / m²"))
            lines.append(MaterialLine(name: "Underlayment rolls", quantity: ceil(area / 18),
                                      unit: "rolls", note: "18 m² per roll"))
            lines.append(MaterialLine(name: "Sealant tubes", quantity: ceil(area / 25),
                                      unit: "tubes", note: "1 tube / 25 m² detailing"))
        case .metal:
            lines.append(MaterialLine(name: "Metal sheets", quantity: ceil(area / 1.5),
                                      unit: "sheets", note: "≈1.5 m² usable per sheet"))
            lines.append(MaterialLine(name: "Screws / clips", quantity: ceil(area * 8),
                                      unit: "pcs", note: "≈8 / m²"))
            lines.append(MaterialLine(name: "Butyl sealant tubes", quantity: ceil(area / 20),
                                      unit: "tubes", note: "1 / 20 m²"))
        case .tile, .slate:
            let perM2 = covering == .tile ? 12.0 : 14.0
            lines.append(MaterialLine(name: covering == .tile ? "Tiles" : "Slates",
                                      quantity: ceil(area * perM2), unit: "pcs",
                                      note: "≈\(Int(perM2)) / m²"))
            lines.append(MaterialLine(name: "Clips / nails", quantity: ceil(area * perM2),
                                      unit: "pcs", note: "1 per piece"))
            lines.append(MaterialLine(name: "Ridge mortar / clips", quantity: ceil(area.squareRoot()),
                                      unit: "pcs", note: "ridge line allowance"))
        case .bitumen:
            lines.append(MaterialLine(name: "Bitumen rolls", quantity: ceil(area / 8),
                                      unit: "rolls", note: "8 m² per roll"))
            lines.append(MaterialLine(name: "Primer", quantity: ceil(area * 0.3),
                                      unit: "L", note: "0.3 L / m²"))
            lines.append(MaterialLine(name: "Torch gas canisters", quantity: ceil(area / 40),
                                      unit: "pcs", note: "1 / 40 m²"))
        case .membrane:
            lines.append(MaterialLine(name: "Membrane rolls", quantity: ceil(area / 45),
                                      unit: "rolls", note: "45 m² per roll"))
            lines.append(MaterialLine(name: "Adhesive", quantity: ceil(area * 0.25),
                                      unit: "L", note: "0.25 L / m²"))
            lines.append(MaterialLine(name: "Seam tape rolls", quantity: ceil(area / 60),
                                      unit: "rolls", note: "1 / 60 m²"))
        }

        // Edge / drip strips common to all (perimeter ≈ sqrt(area) * 4).
        let edgeMeters = area.squareRoot() * 4
        lines.append(MaterialLine(name: "Edge / drip strips", quantity: ceil(edgeMeters / 2),
                                  unit: "pcs", note: "2 m strips"))

        return MaterialBill(totalArea: net, lines: lines)
    }
}
