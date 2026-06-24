import Foundation

enum Move {
    case rescan
    case hold(Shot)
    case land(Shot)
}

protocol Spec {
    func holds(for sweep: Sweep) -> Bool
}

struct Both: Spec {
    let a: Spec
    let b: Spec
    func holds(for sweep: Sweep) -> Bool { a.holds(for: sweep) && b.holds(for: sweep) }
}

struct Either: Spec {
    let a: Spec
    let b: Spec
    func holds(for sweep: Sweep) -> Bool { a.holds(for: sweep) || b.holds(for: sweep) }
}

struct Inverse: Spec {
    let inner: Spec
    func holds(for sweep: Sweep) -> Bool { !inner.holds(for: sweep) }
}

struct OverlayWaiting: Spec {
    func holds(for sweep: Sweep) -> Bool {
        guard let url = UserDefaults.standard.string(forKey: RoofKey.pushURL) else { return false }
        return !url.isEmpty
    }
}

struct Captured: Spec {
    func holds(for sweep: Sweep) -> Bool { sweep.captured }
}

struct Hazy: Spec {
    func holds(for sweep: Sweep) -> Bool { sweep.organicHaze }
}

struct Grounded: Spec {
    func holds(for sweep: Sweep) -> Bool { sweep.grounded }
}

struct Reflown: Spec {
    func holds(for sweep: Sweep) -> Bool { sweep.flown }
}

final class Flight {
    var sweep: Sweep
    let kit: Kit

    init(sweep: Sweep, kit: Kit) {
        self.sweep = sweep
        self.kit = kit
    }

    func develop(url: String) -> Shot {
        let needsClearance = sweep.passDue

        sweep.tileURL = url
        sweep.tileMode = "Active"
        sweep.grounded = false
        sweep.charted = true

        kit.spool.commit(sweep.log())
        kit.spool.markTile(url: url, mode: "Active")
        kit.spool.raisePrimedFlag()
        UserDefaults.standard.removeObject(forKey: RoofKey.pushURL)

        return needsClearance ? .askClearance : .render
    }
}

protocol Pass: AnyObject {
    func run(_ flight: Flight) async -> Move
}
