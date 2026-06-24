import Foundation

final class Kit {
    let spool: Spool
    let lidar: Lidar
    let skylink: Skylink
    let clearance: Clearance

    init(spool: Spool, lidar: Lidar, skylink: Skylink, clearance: Clearance) {
        self.spool = spool
        self.lidar = lidar
        self.skylink = skylink
        self.clearance = clearance
    }

    static func loadout() -> Kit {
        Kit(
            spool: ReelSpool(),
            lidar: PulsedLidar(),
            skylink: SatSkylink(),
            clearance: TowerClearance()
        )
    }
}

@MainActor
final class Airfield {

    static let shared = Airfield()

    private var bays: [String: Any] = [:]

    private init() {}

    func park<T>(_ instance: T, as type: T.Type) {
        bays[String(describing: type)] = instance
    }

    func launch<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        if let instance = bays[key] as? T {
            return instance
        }
        let built = roll(type)
        bays[key] = built
        return built
    }

    private func roll<T>(_ type: T.Type) -> T {
        switch String(describing: type) {
        case String(describing: Kit.self):
            return Kit.loadout() as! T
        case String(describing: Pilot.self):
            return Pilot(kit: launch(Kit.self)) as! T
        default:
            fatalError("Airfield: no builder for \(type)")
        }
    }
}
