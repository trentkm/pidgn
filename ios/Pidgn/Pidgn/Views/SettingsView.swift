//
//  SettingsView.swift
//  Pidgn
//
//  Settings screen with household info, invite code generation, and sign out.

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AuthService.self) var authService
    @State private var inviteCode: String?
    @State private var isGeneratingInvite = false
    @State private var errorMessage: String?
    @State private var copiedHouseholdId = false

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Profile") {
                    if let name = authService.userProfile?.displayName {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(name).foregroundStyle(.secondary)
                        }
                    }
                    if let email = authService.userProfile?.email {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email).foregroundStyle(.secondary)
                        }
                    }
                }

                // Household
                if let householdId {
                    Section("Household") {
                        HStack {
                            Text("Household ID")
                            Spacer()
                            Text(householdId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            UIPasteboard.general.string = householdId
                            copiedHouseholdId = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedHouseholdId = false
                            }
                        }

                        if copiedHouseholdId {
                            Text("Copied to clipboard!")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    // Invite
                    Section("Invite Members") {
                        if let code = inviteCode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Invite Code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(code)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospaced()

                                Button("Copy Code") {
                                    UIPasteboard.general.string = code
                                }
                                .font(.caption)
                            }
                        }

                        Button {
                            Task { await generateInvite() }
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
                        .disabled(isGeneratingInvite)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                // Sign out
                Section {
                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
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
    SettingsView()
        .environment(AuthService())
}
