import Foundation
import UIKit
import UserNotifications

protocol Clearance {
    func seek() async -> Bool
    func armBeacon()
}

final class TowerClearance: Clearance {

    func seek() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let strobe = OneStrobe()
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if let error = error {
                    print("\(Roof.logCopter) Clearance error: \(error)")
                }
                DispatchQueue.main.async {
                    guard strobe.flash() else { return }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func armBeacon() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

final class OneStrobe {
    private var flashed = false
    private let lock = NSLock()

    func flash() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !flashed else { return false }
        flashed = true
        return true
    }
}
