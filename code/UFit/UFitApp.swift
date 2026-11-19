import SwiftUI

@main
struct UFitApp: App {
    @UIApplicationDelegateAdaptor(UFitNotificationsDelegate.self) private var notifications
    var body: some Scene {
        WindowGroup {
            MarketplaceRootView(notifications: notifications)
        }
    }
}
