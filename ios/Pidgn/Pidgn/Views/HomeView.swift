//
//  HomeView.swift
//  Pidgn
//
//  Placeholder home screen for Phase 1. Will become the mailbox in Phase 2.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var inviteCode: String?
    @State private var isGeneratingInvite = false
    @State private var errorMessage: String?

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Welcome
                VStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("Welcome to Pidgn")
                        .font(.title)
                        .fontWeight(.bold)
                    if let name = authService.userProfile?.displayName {
                        Text("Signed in as \(name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Household info
                if let householdId {
                    VStack(spacing: 12) {
                        Text("Your household is set up.")
                            .font(.headline)

                        // Invite code section
                        if let code = inviteCode {
                            VStack(spacing: 8) {
                                Text("Invite Code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(code)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospaced()
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                Button("Copy Code") {
                                    UIPasteboard.general.string = code
                                }
                                .font(.caption)
                            }
                        }

                        Button {
                            Task {
                                await generateInvite()
                            }
                        } label: {
                            if isGeneratingInvite {
                                ProgressView()
                            } else {
                                Label(
                                    inviteCode == nil ? "Generate Invite Code" : "Generate New Code",
                                    systemImage: "link.badge.plus"
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGeneratingInvite)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Text("Mailbox coming in Phase 2")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        authService.signOut()
                    }
                }
            }
        }
    }

    private func generateInvite() async {
        guard let householdId else { return }
        isGeneratingInvite = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.generateInvite(householdId: householdId)
            inviteCode = response.inviteCode
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingInvite = false
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
}
