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
    @State private var pendingInviteCode: String?
    @State private var pendingFlockId: String?

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
        PushNotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                shouldOpenUnread: $shouldOpenUnread,
                pendingInviteCode: $pendingInviteCode,
                pendingFlockId: $pendingFlockId
            )
            .environment(authService)
            .onOpenURL { url in
                handleUniversalLink(url)
            }
        }
    }

    private func handleUniversalLink(_ url: URL) {
        guard url.host == "pidgn.app" || url.host == "www.pidgn.app" else {
            return
        }

        if url.path == "/open" {
            shouldOpenUnread = true
        } else if url.pathComponents.count >= 3,
                  url.pathComponents[1] == "invite" {
            pendingInviteCode = url.pathComponents[2]
        } else if url.pathComponents.count >= 3,
                  url.pathComponents[1] == "flock" {
            pendingFlockId = url.pathComponents[2]
        }
    }
}
