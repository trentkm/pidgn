//
//  ContentView.swift
//  Pidgn
//
//  Root navigator: routes to auth, household setup, or home based on user state.
//
//  Created by Trent Morrell on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isLoading {
                // Splash / loading state while Firebase checks auth
                VStack(spacing: 16) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("Pidgn")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    ProgressView()
                }
            } else if !authService.isAuthenticated {
                SignInView()
            } else if authService.userProfile?.householdId == nil {
                HouseholdSetupView()
            } else {
                HomeView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
