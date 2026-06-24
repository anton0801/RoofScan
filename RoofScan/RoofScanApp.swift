import SwiftUI

@main
struct RoofScanApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var applicationDelegate
    
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}
