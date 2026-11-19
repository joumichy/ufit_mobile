import Foundation
import UIKit
import UserNotifications
import Observation

@MainActor @Observable
final class UFitNotificationsDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private(set) var pendingNotificationID: String?
    @ObservationIgnored weak var device: UFitNotificationDeviceStore?
    private enum Contract { static let payloadID = "notificationId", pendingKey = "ufit.notification.os-pending" }
    override init() {
        super.init()
        if let value = UserDefaults.standard.string(forKey: Contract.pendingKey), UFitInstallationHTTP.identifier(value) { pendingNotificationID = value }
        else { UserDefaults.standard.removeObject(forKey: Contract.pendingKey) }
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self; return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { device?.received(token: deviceToken) }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { device?.registrationFailed() }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.content.userInfo[Contract.payloadID] as? String
        let shouldOpen = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        Task { @MainActor in
            if shouldOpen, let id, UFitInstallationHTTP.identifier(id) {
                UserDefaults.standard.set(id, forKey: Contract.pendingKey); pendingNotificationID = id
            }
            completionHandler()
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.content.userInfo[Contract.payloadID] as? String
        Task { @MainActor in
            let allowed: Bool
            if let id, UFitInstallationHTTP.identifier(id), let device { allowed = await device.mayPresent(id: id) }
            else { allowed = false }
            completionHandler(allowed ? [.banner, .list, .sound] : [])
        }
    }
    func consumedNotification(_ id: String) {
        guard pendingNotificationID == id else { return }
        UserDefaults.standard.removeObject(forKey: Contract.pendingKey); pendingNotificationID = nil
    }
}
