import Foundation

struct SweepLog: Codable {
    let capture: [String: String]
    let pins: [String: String]
    let tileURL: String?
    let tileMode: String?
    let grounded: Bool
    let passGranted: Bool
    let passDenied: Bool
    let passAt: Date?
}

struct Sweep {
    var capture: [String: String] = [:]
    var pins: [String: String] = [:]
    var tileURL: String? = nil
    var tileMode: String? = nil
    var grounded: Bool = true
    var charted: Bool = false
    var flown: Bool = false
    var passGranted: Bool = false
    var passDenied: Bool = false
    var passAt: Date? = nil

    var captured: Bool { !capture.isEmpty }
    var organicHaze: Bool { capture["af_status"] == "Organic" }

    var passDue: Bool {
        guard !passGranted && !passDenied else { return false }
        if let date = passAt {
            return Date().timeIntervalSince(date) / 86400 >= 3
        }
        return true
    }

    static func restore(from log: SweepLog) -> Sweep {
        var s = Sweep()
        s.capture = log.capture
        s.pins = log.pins
        s.tileURL = log.tileURL
        s.tileMode = log.tileMode
        s.grounded = log.grounded
        s.passGranted = log.passGranted
        s.passDenied = log.passDenied
        s.passAt = log.passAt
        return s
    }

    func log() -> SweepLog {
        SweepLog(
            capture: capture,
            pins: pins,
            tileURL: tileURL,
            tileMode: tileMode,
            grounded: grounded,
            passGranted: passGranted,
            passDenied: passDenied,
            passAt: passAt
        )
    }
}

enum Shot: Equatable {
    case scanning
    case askClearance
    case render
    case aborted
}
