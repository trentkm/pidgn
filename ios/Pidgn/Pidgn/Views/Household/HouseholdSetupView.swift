//
//  HouseholdSetupView.swift
//  Pidgn
//

import SwiftUI

struct HouseholdSetupView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "house.and.flag.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("Set Up Your Household")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Create a new household or join an existing one to start sending mail.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    NavigationLink {
                        CreateHouseholdView()
                    } label: {
                        Label("Create a New Household", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    NavigationLink {
                        JoinHouseholdView()
                    } label: {
                        Label("Join an Existing Household", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                Button("Sign Out") {
                    authService.signOut()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    HouseholdSetupView()
        .environmentObject(AuthService())
}
