//
//  PidgnApp.swift
//  Pidgn
//
//  Created by Trent Morrell on 3/7/26.
//
//  NOTE: Requires FirebaseAuth and FirebaseFirestore packages added via SPM in Xcode.
//  Add package: https://github.com/firebase/firebase-ios-sdk
//  Select products: FirebaseAuth, FirebaseFirestore

import SwiftUI
import FirebaseCore

@main
struct PidgnApp: App {
    @StateObject private var authService = AuthService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
