import Foundation
import Combine

@MainActor
final class Pilot {

    private var sweep = Sweep()
    private var primed = false
    private var sealed = false
    private var flying = false

    private let kit: Kit
    private let rules: [(Spec, Pass)]

    private let shotSubject = PassthroughSubject<Shot, Never>()
    var shotPublisher: AnyPublisher<Shot, Never> {
        shotSubject.eraseToAnyPublisher()
    }

    private var clearanceTask: Task<Void, Never>?

    init(kit: Kit) {
        self.kit = kit
        self.rules = [
            (OverlayWaiting(), OverlayPass()),
            (Inverse(inner: Captured()), HoldPass(.scanning)),
            (Both(a: Hazy(), b: Both(a: Grounded(), b: Inverse(inner: Reflown()))), ReflightPass()),
            (Captured(), BeamPass())
        ]
    }

    private func ensurePrimed() {
        guard !primed else { return }
        sweep = Sweep.restore(from: kit.spool.pull())
        primed = true
    }

    private func seal() -> Bool {
        guard !sealed else { return false }
        sealed = true
        return true
    }

    func warmUp() {
        ensurePrimed()
    }

    func loadCapture(_ raw: [String: Any]) {
        ensurePrimed()
        sweep.capture = raw.mapValues { "\($0)" }
        kit.spool.commit(sweep.log())
    }

    func loadPins(_ raw: [String: Any]) {
        ensurePrimed()
        sweep.pins = raw.mapValues { "\($0)" }
        kit.spool.commit(sweep.log())
    }

    func scan() async {
        ensurePrimed()
        guard !sealed, !flying else { return }
        flying = true
        defer { flying = false }

        let flight = Flight(sweep: sweep, kit: kit)
        var cycles = 0

        while cycles < 8 {
            cycles += 1
            guard let rule = rules.first(where: { $0.0.holds(for: flight.sweep) }) else { break }
            let move = await rule.1.run(flight)
            switch move {
            case .rescan:
                continue
            case .hold(let shot):
                sweep = flight.sweep
                shotSubject.send(shot)
                return
            case .land(let shot):
                sweep = flight.sweep
                if seal() {
                    shotSubject.send(shot)
                }
                return
            }
        }

        sweep = flight.sweep
        shotSubject.send(.scanning)
    }

    func grantClearance(then ack: @escaping () -> Void) {
        ensurePrimed()
        clearanceTask = Task { [weak self] in
            guard let self = self else { return }

            let granted = await self.kit.clearance.seek()

            self.sweep.passGranted = granted
            self.sweep.passDenied = !granted
            self.sweep.passAt = Date()
            self.kit.spool.commit(self.sweep.log())

            if granted {
                self.kit.clearance.armBeacon()
            }

            self.shotSubject.send(.render)
            ack()
        }
    }

    func skipClearance() {
        ensurePrimed()
        sweep.passAt = Date()
        kit.spool.commit(sweep.log())
        shotSubject.send(.render)
    }

    func reportTimeout() -> Bool {
        return seal()
    }
}
