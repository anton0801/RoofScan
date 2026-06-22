//
//  PDFReportService.swift
//  RoofScan
//
//  Builds a multi-section roof defect report PDF with UIGraphicsPDFRenderer:
//  health summary, service-life estimate, defect schedule, repair totals, photos.
//

import UIKit

enum PDFReportService {

    private static let pageSize = CGSize(width: 595, height: 842) // A4 @72dpi
    private static let margin: CGFloat = 40

    static func generate(project: RoofProject,
                         settings: ReportSettings) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoofScan-Report.pdf")

        let life = ServiceLifeEngine.estimate(project: project)
        let health = ServiceLifeEngine.health(project: project)
        let repair = RepairCostEngine.estimate(defects: project.defects,
                                               hourlyRate: settings.hourlyRate,
                                               currency: settings.currency)

        do {
            try renderer.writePDF(to: url) { ctx in
                var cursor = Cursor(ctx: ctx, pageSize: pageSize, margin: margin)
                cursor.beginPage()

                cursor.title("Roof Defect Report")
                cursor.muted(Self.dateString(Date()))
                cursor.gap(10)

                // Overview
                cursor.heading("Overview")
                cursor.line("Roof type: \(project.roofType.label)")
                cursor.line("Covering: \(project.covering.label) · age \(project.ageYears) yr")
                cursor.line("Slopes: \(project.slopes.count) · total area \(Self.area(project.totalArea, settings))")
                cursor.line("Roof health: \(health.overall)%")
                cursor.gap(8)

                // Service life
                cursor.heading("Service-life estimate")
                cursor.line("Remaining life: \(String(format: "%.1f", life.remainingYears)) years")
                cursor.line("Recommendation: \(life.tier.label)")
                for f in life.topFactors {
                    cursor.bullet("\(f.label): −\(String(format: "%.1f", f.yearsLost)) yr")
                }
                cursor.gap(8)

                // Defect schedule grouped by slope
                cursor.heading("Defect schedule")
                if project.defects.isEmpty {
                    cursor.muted("No defects recorded.")
                } else {
                    for slope in project.slopes {
                        let ds = project.defects(on: slope.id)
                        guard !ds.isEmpty else { continue }
                        cursor.subheading(slope.name)
                        for d in ds {
                            cursor.bullet("\(d.type.label) — sev \(d.severity) — \(d.status.label)"
                                          + (d.note.isEmpty ? "" : " — \(d.note)"))
                        }
                    }
                    let unassigned = project.defects.filter { d in
                        !project.slopes.contains { $0.id == d.slopeID }
                    }
                    if !unassigned.isEmpty {
                        cursor.subheading("Unassigned")
                        for d in unassigned {
                            cursor.bullet("\(d.type.label) — sev \(d.severity) — \(d.status.label)")
                        }
                    }
                }
                cursor.gap(8)

                // Repair cost
                cursor.heading("Repair cost estimate")
                cursor.line("Do-now total: \(settings.currency)\(Self.money(repair.doNowTotal))")
                cursor.line("Full total: \(settings.currency)\(Self.money(repair.total))")
                for l in repair.lines.prefix(20) {
                    cursor.bullet("\(l.label): \(settings.currency)\(Self.money(l.total))"
                                  + (l.doNow ? "  [DO NOW]" : ""))
                }
                cursor.gap(8)

                // Photos
                let photos = settings.includePhotos ? Array(project.photos.prefix(6)) : []
                if !photos.isEmpty {
                    cursor.heading("Photo evidence")
                    for p in photos {
                        if let img = PhotoStore.shared.load(p.filename) {
                            cursor.image(img, caption: p.caption.isEmpty ? "Photo" : p.caption)
                        }
                    }
                }

                cursor.gap(14)
                cursor.muted("Estimate only — does not replace an on-site inspection by a qualified roofer.")
            }
            return url
        } catch {
            return nil
        }
    }

    struct ReportSettings {
        var currency: String
        var hourlyRate: Double
        var unitSystem: UnitSystem
        var includePhotos: Bool = true
    }

    // MARK: helpers
    private static func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: d)
    }
    private static func money(_ v: Double) -> String { String(format: "%.0f", v) }
    private static func area(_ m2: Double, _ s: ReportSettings) -> String {
        String(format: "%.0f %@", m2 * s.unitSystem.areaFactor, s.unitSystem.areaUnit)
    }
}

/// Simple top-down text/image cursor with automatic page breaks.
private struct Cursor {
    let ctx: UIGraphicsPDFRendererContext
    let pageSize: CGSize
    let margin: CGFloat
    var y: CGFloat = 0

    init(ctx: UIGraphicsPDFRendererContext, pageSize: CGSize, margin: CGFloat) {
        self.ctx = ctx; self.pageSize = pageSize; self.margin = margin; self.y = margin
    }

    var maxY: CGFloat { pageSize.height - margin }
    var width: CGFloat { pageSize.width - margin * 2 }

    mutating func beginPage() { ctx.beginPage(); y = margin }
    mutating func ensure(_ h: CGFloat) { if y + h > maxY { beginPage() } }
    mutating func gap(_ h: CGFloat) { y += h }

    mutating func draw(_ text: String, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        ensure(bounding.height + 4)
        (text as NSString).draw(with: CGRect(x: margin, y: y, width: width, height: bounding.height),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: attrs, context: nil)
        y += bounding.height + 4
    }

    mutating func title(_ t: String)      { draw(t, font: .systemFont(ofSize: 24, weight: .bold), color: .black) }
    mutating func heading(_ t: String)    { gap(6); draw(t, font: .systemFont(ofSize: 16, weight: .bold), color: UIColor(red: 0.18, green: 0.42, blue: 1, alpha: 1)) }
    mutating func subheading(_ t: String) { draw(t, font: .systemFont(ofSize: 13, weight: .semibold), color: .darkGray) }
    mutating func line(_ t: String)       { draw(t, font: .systemFont(ofSize: 12, weight: .regular), color: .black) }
    mutating func bullet(_ t: String)     { draw("•  " + t, font: .systemFont(ofSize: 12, weight: .regular), color: .black) }
    mutating func muted(_ t: String)      { draw(t, font: .systemFont(ofSize: 10, weight: .regular), color: .gray) }

    mutating func image(_ img: UIImage, caption: String) {
        let targetW: CGFloat = 200
        let ratio = img.size.height / max(1, img.size.width)
        let targetH = targetW * ratio
        ensure(targetH + 18)
        img.draw(in: CGRect(x: margin, y: y, width: targetW, height: targetH))
        y += targetH + 2
        muted(caption)
    }
}
