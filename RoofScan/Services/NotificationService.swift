//
//  NotificationService.swift
//  RoofScan
//
//  Real UNUserNotificationCenter wrapper for seasonal / post-storm /
//  gutter-cleaning / critical-recheck reminders. All local notifications.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    /// Ask for permission. Completion returns the granted state on the main queue.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Schedule (or reschedule) a reminder. Repeating reminders fire yearly
    /// on the same month/day/time; one-shots fire at the exact date.
    func schedule(_ reminder: Reminder) {
        cancel(id: reminder.notificationID)
        guard reminder.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default

        let cal = Calendar.current
        let trigger: UNNotificationTrigger
        if reminder.repeats {
            let comps = cal.dateComponents([.month, .day, .hour, .minute], from: reminder.fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        } else {
            let interval = max(1, reminder.fireDate.timeIntervalSinceNow)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        }

        let request = UNNotificationRequest(identifier: reminder.notificationID,
                                            content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Debug helper — fire in `seconds` so reminders can be tested instantly.
    func scheduleTest(title: String, body: String, after seconds: TimeInterval, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    func pendingIDs(_ completion: @escaping (Set<String>) -> Void) {
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(Set(requests.map { $0.identifier }))
            }
        }
    }
}
