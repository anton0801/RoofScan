import Foundation

enum RoofKey {
    static let tileURL = "rs_tile_url"
    static let tileMode = "rs_tile_mode"
    static let primed = "rs_primed"

    static let passGranted = "rs_pass_granted"
    static let passDenied = "rs_pass_denied"
    static let passAt = "rs_pass_at"

    static let pushURL = "temp_url"
    static let fcm = "fcm_token"
    static let push = "push_token"
}

extension Notification.Name {
    static let captureArrived = Notification.Name("ConversionDataReceived")
    static let pinsArrived = Notification.Name("deeplink_values")
    static let renderWake = Notification.Name("LoadTempURL")
}

enum Smear: Error, CustomStringConvertible {
    case blankScan(at: String)
    case skewed(at: String)
    case faded(stage: String)
    case clouded(cooldown: TimeInterval)
    case gridLocked(httpCode: Int)
    case surveyDenied(reason: String)
    case smudged(at: String)

    var description: String {
        switch self {
        case .blankScan(let at): return "blankScan(\(at))"
        case .skewed(let at): return "skewed(\(at))"
        case .faded(let stage): return "faded(\(stage))"
        case .clouded(let cd): return "clouded(cd=\(cd))"
        case .gridLocked(let code): return "gridLocked(\(code))"
        case .surveyDenied(let reason): return "surveyDenied(\(reason))"
        case .smudged(let at): return "smudged(\(at))"
        }
    }

    var isSealed: Bool {
        switch self {
        case .gridLocked, .surveyDenied: return true
        default: return false
        }
    }
}
