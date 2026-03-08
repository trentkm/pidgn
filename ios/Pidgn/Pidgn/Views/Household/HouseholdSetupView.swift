//
//  HouseholdSetupView.swift
//  Pidgn
//
//  Build your nest — create or join a household.

import SwiftUI

struct HouseholdSetupView: View {
    @Environment(AuthService.self) var authService

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Warm illustration area
                ZStack {
                    Circle()
                        .fill(PidgnTheme.sand)
                        .frame(width: 130, height: 130)

                    Image(systemName: "house.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(PidgnTheme.accent)
                }

                VStack(spacing: 8) {
                    Text("Build Your Nest")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("A nest is your household — the home\nyour letters fly to and from.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    NavigationLink {
                        CreateHouseholdView()
                    } label: {
                        Label("Create a Nest", systemImage: "plus.circle.fill")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PidgnTheme.accent)
                    .controlSize(.large)

                    NavigationLink {
                        JoinHouseholdView()
                    } label: {
                        Label("Join an Existing Nest", systemImage: "person.badge.plus")
                            .font(.system(.body, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PidgnTheme.accent)
                    .controlSize(.large)
                }

                Spacer()

                Button("Sign Out") {
                    authService.signOut()
                }
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    HouseholdSetupView()
        .environment(AuthService())
}
