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
    @Environment(AuthService.self) var authService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Binding var shouldOpenUnread: Bool
    @Binding var pendingInviteCode: String?
    @Binding var pendingFlockId: String?

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if authService.isLoading {
                // Warm loading with personality
                VStack(spacing: 20) {
                    Image(systemName: "bird.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(PidgnTheme.accent)
                        .symbolEffect(.bounce, options: .repeating.speed(0.5))

                    VStack(spacing: 6) {
                        Text("Pidgn")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Letters carried with care.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !authService.isAuthenticated {
                SignInView()
            } else if let code = pendingInviteCode {
                InviteJoinView(
                    inviteCode: code,
                    onDismiss: { pendingInviteCode = nil }
                )
            } else if authService.userProfile?.householdId == nil {
                HouseholdSetupView()
            } else if let flockId = pendingFlockId {
                FlockConnectView(
                    targetHouseholdId: flockId,
                    onDismiss: { pendingFlockId = nil }
                )
            } else {
                MainTabView(shouldOpenUnread: $shouldOpenUnread)
            }
        }
    }
}

#Preview {
    ContentView(
        shouldOpenUnread: .constant(false),
        pendingInviteCode: .constant(nil),
        pendingFlockId: .constant(nil)
    )
    .environment(AuthService())
}
