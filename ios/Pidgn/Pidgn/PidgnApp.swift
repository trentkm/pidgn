//
//  PidgnApp.swift
//  Pidgn
//
//  Created by Trent Morrell on 3/7/26.
//
//  NOTE: Requires Firebase packages added via SPM in Xcode.
//  Add package: https://github.com/firebase/firebase-ios-sdk
//  Select products: FirebaseAuth, FirebaseFirestore, FirebaseMessaging

import SwiftUI
import FirebaseCore

@main
struct PidgnApp: App {
    @State private var authService: AuthService
    @State private var shouldOpenUnread = false

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
        PushNotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(shouldOpenUnread: $shouldOpenUnread)
                .environment(authService)
                .onOpenURL { url in
                    handleUniversalLink(url)
                }
        }
    }

    private func handleUniversalLink(_ url: URL) {
        // Universal Link: https://pidgn.app/open
        guard url.host == "pidgn.app" || url.host == "www.pidgn.app",
              url.path == "/open" else {
            return
        }

        // Trigger mailbox to open all unread messages
        shouldOpenUnread = true
    }
}
