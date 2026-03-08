//
//  PushNotificationService.swift
//  Pidgn
//
//  Handles FCM token registration and push notification setup.
//  NOTE: Requires FirebaseMessaging package added via SPM in Xcode.
//        Add product: FirebaseMessaging

import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

class PushNotificationService: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private override init() {
        super.init()
    }

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        requestPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                print("Push notification permission error: \(error.localizedDescription)")
                return
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM token received: \(token)")

        Task {
            await registerToken(token)
        }
    }

    private func registerToken(_ token: String) async {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            print("Could not get device identifier")
            return
        }

        do {
            try await APIService.shared.registerFCMToken(token: token, deviceId: deviceId)
            print("FCM token registered with server")
        } catch {
            print("Failed to register FCM token: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
