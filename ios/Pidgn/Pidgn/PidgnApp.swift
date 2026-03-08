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

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
        PushNotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
    }
}
