//
//  MorphPushAppDelegate.swift
//  App
//

import UIKit
import UserNotifications

final class MorphPushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        print("📦 [App] buildConfiguration = \(MorphH5Config.buildConfigurationLabel)")
        #endif
        MorphPushManager.shared.startAutomaticRegistration()
        MorphPushManager.logCurrentDeviceTokenIfAvailable()

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            MorphPushManager.shared.captureLaunchPayload(userInfo, source: "coldStart")
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MorphPushManager.shared.updateDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        MorphPushManager.shared.updateRegistrationFailure(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let state = application.applicationState
        MorphPushManager.shared.deliverPayload(
            userInfo,
            source: state == .active ? "remoteNotification.foreground" : "remoteNotification.\(state.rawValue)"
        )
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        MorphPushManager.shared.deliverPayload(userInfo, source: "willPresent.foreground")
        completionHandler(Self.foregroundPresentationOptions)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        MorphPushManager.shared.deliverPayload(
            response.notification.request.content.userInfo,
            source: "didReceive.tap"
        )
        completionHandler()
    }

    private static var foregroundPresentationOptions: UNNotificationPresentationOptions {
        if #available(iOS 14.0, *) {
            return [.banner, .list, .sound, .badge]
        }
        return [.alert, .sound, .badge]
    }
}
