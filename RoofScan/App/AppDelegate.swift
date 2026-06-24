import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private let stitch = Stitch()
    private let cull = Cull()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        AppDelegate.assemble([
            AppDelegate.igniteFirebase,
            AppDelegate.fitTracker,
            AppDelegate.fitMessaging,
            AppDelegate.fitAlarms
        ])(self)

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            cull.gather(remote)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func onActivation() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: "att_status")
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }

    private static func assemble(_ steps: [(AppDelegate) -> Void]) -> (AppDelegate) -> Void {
        steps.reduce({ _ in }) { composed, step in
            { host in
                composed(host)
                step(host)
            }
        }
    }

    private static func igniteFirebase(_ host: AppDelegate) {
        FirebaseApp.configure()
    }

    private static func fitTracker(_ host: AppDelegate) {
        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = Roof.lidarKey
        sdk.appleAppID = Roof.appCode
        sdk.delegate = host
        sdk.deepLinkDelegate = host
        sdk.isDebug = false
    }

    private static func fitMessaging(_ host: AppDelegate) {
        Messaging.messaging().delegate = host
        UIApplication.shared.registerForRemoteNotifications()
    }

    private static func fitAlarms(_ host: AppDelegate) {
        UNUserNotificationCenter.current().delegate = host
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, err in
            guard err == nil, let t = token else { return }
            UserDefaults.standard.set(t, forKey: RoofKey.fcm)
            UserDefaults.standard.set(t, forKey: RoofKey.push)
            UserDefaults(suiteName: Roof.suiteSurvey)?.set(t, forKey: "shared_fcm")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        cull.gather(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        cull.gather(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        cull.gather(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        stitch.takeCapture(data)
    }

    func onConversionDataFail(_ error: Error) {
        stitch.takeCapture([
            "error": true,
            "error_desc": error.localizedDescription
        ])
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let link = result.deepLink else { return }
        stitch.takePins(link.clickEvent)
    }
}

final class Stitch {

    private var captureBuffer: [AnyHashable: Any] = [:]
    private var pinsBuffer: [AnyHashable: Any] = [:]
    private var fuse: Timer?

    func takeCapture(_ data: [AnyHashable: Any]) {
        captureBuffer = data
        armFuse()
        if !pinsBuffer.isEmpty { weave() }
    }

    func takePins(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: RoofKey.primed) else { return }
        pinsBuffer = data
        NotificationCenter.default.post(
            name: .pinsArrived,
            object: nil,
            userInfo: ["deeplinksData": data]
        )
        cancelFuse()
        if !captureBuffer.isEmpty { weave() }
    }

    private func armFuse() {
        cancelFuse()
        let timer = Timer(timeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.weave()
        }
        RunLoop.main.add(timer, forMode: .common)
        fuse = timer
    }

    private func cancelFuse() {
        fuse?.invalidate()
        fuse = nil
    }

    private func weave() {
        cancelFuse()
        var woven = captureBuffer
        for (k, v) in pinsBuffer {
            let tag = "deep_\(k)"
            if woven[tag] == nil { woven[tag] = v }
        }
        NotificationCenter.default.post(
            name: .captureArrived,
            object: nil,
            userInfo: ["conversionData": woven]
        )
    }
}

final class Cull {

    func gather(_ payload: [AnyHashable: Any]) {
        guard let url = pick(payload) else { return }
        UserDefaults.standard.set(url, forKey: RoofKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(
                name: .renderWake,
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }

    private func pick(_ payload: [AnyHashable: Any]) -> String? {
        let root = payload as NSDictionary
        func nest(_ any: Any?) -> NSDictionary? { any as? NSDictionary }
        return (root["url"] as? String)
            ?? (nest(root["data"])?["url"] as? String)
            ?? (nest(nest(root["aps"])?["data"])?["url"] as? String)
            ?? (nest(root["custom"])?["url"] as? String)
    }
}
