import Foundation
import AppsFlyerLib

final class HoldPass: Pass {
    private let shot: Shot

    init(_ shot: Shot) {
        self.shot = shot
    }

    func run(_ flight: Flight) async -> Move {
        .hold(shot)
    }
}

final class OverlayPass: Pass {
    func run(_ flight: Flight) async -> Move {
        let url = UserDefaults.standard.string(forKey: RoofKey.pushURL) ?? ""
        return .land(flight.develop(url: url))
    }
}

final class ReflightPass: Pass {
    func run(_ flight: Flight) async -> Move {
        flight.sweep.flown = true
        flight.kit.spool.commit(flight.sweep.log())

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard !flight.sweep.charted else { return .rescan }

        let id = AppsFlyerLib.shared().getAppsFlyerUID()
        do {
            let pinged = try await flight.kit.lidar.ping(deviceID: id)
            let stringPinged = pinged.mapValues { "\($0)" }
            let merged = Dictionary(
                flight.sweep.pins.map { ($0.key, $0.value) } + stringPinged.map { ($0.key, $0.value) },
                uniquingKeysWith: { _, fresh in fresh }
            )
            flight.sweep.capture = merged
            flight.kit.spool.commit(flight.sweep.log())
        } catch {
            print("\(Roof.logCopter) reflight soft fail: \(error)")
        }

        return .rescan
    }
}

final class BeamPass: Pass {
    func run(_ flight: Flight) async -> Move {
        let payload = flight.sweep.capture.mapValues { $0 as Any }
        do {
            let url = try await flight.kit.skylink.relay(payload: payload)
            return .land(flight.develop(url: url))
        } catch {
            return .land(.aborted)
        }
    }
}
