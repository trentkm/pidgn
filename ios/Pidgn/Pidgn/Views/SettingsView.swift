//
//  SettingsView.swift
//  Pidgn
//
//  Your nest — household settings, magnet setup, and account.

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AuthService.self) var authService
    @State private var inviteCode: String?
    @State private var isGeneratingInvite = false
    @State private var errorMessage: String?
    @State private var copiedHouseholdId = false
    @State private var isSettingUpMagnet = false
    @State private var magnetSetupResult: String?

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section {
                    HStack(spacing: 14) {
                        Text(String((authService.userProfile?.displayName ?? "?").prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(PidgnTheme.accent, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.userProfile?.displayName ?? "")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Text(authService.userProfile?.email ?? "")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Household
                if let householdId {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nest ID")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text(copiedHouseholdId ? "Copied!" : householdId)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(copiedHouseholdId ? PidgnTheme.sage : .primary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: copiedHouseholdId ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(copiedHouseholdId ? PidgnTheme.sage : .secondary)
                                .font(.system(size: 14))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIPasteboard.general.string = householdId
                            withAnimation { copiedHouseholdId = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copiedHouseholdId = false }
                            }
                        }
                    } header: {
                        Text("Your Nest")
                    } footer: {
                        Text("Share this with family so they can find your nest.")
                    }

                    // Invite
                    Section {
                        if let code = inviteCode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(code)
                                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                    .tracking(3)

                                Button {
                                    UIPasteboard.general.string = code
                                } label: {
                                    Label("Copy Code", systemImage: "doc.on.doc")
                                        .font(.system(size: 13, design: .rounded))
                                }
                                .tint(PidgnTheme.accent)
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
                                .font(.system(.body, design: .rounded))
                            }
                        }
                        .tint(PidgnTheme.accent)
                        .disabled(isGeneratingInvite)
                    } header: {
                        Text("Invite to the Nest")
                    } footer: {
                        Text("Give this code to someone you'd like to join your household.")
                    }
                }

                // Magnet
                Section {
                    Button {
                        setupMagnet()
                    } label: {
                        HStack {
                            if isSettingUpMagnet {
                                ProgressView()
                            } else {
                                Label("Set Up Your Magnet", systemImage: "wave.3.right")
                                    .font(.system(.body, design: .rounded))
                            }
                        }
                    }
                    .tint(PidgnTheme.accent)
                    .disabled(isSettingUpMagnet)

                    if let result = magnetSetupResult {
                        HStack(spacing: 8) {
                            Image(systemName: result.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(result)
                        }
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(result.contains("Success") ? PidgnTheme.sage : .red)
                    }
                } header: {
                    Text("Fridge Magnet")
                } footer: {
                    Text("Hold your phone near a blank NFC tag. Once programmed, tapping the magnet opens sealed letters.")
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
                    .font(.system(.body, design: .rounded))
                }
            }
            .navigationTitle("Nest")
        }
    }

    private func setupMagnet() {
        isSettingUpMagnet = true
        magnetSetupResult = nil

        NFCService.shared.writeTag { result in
            DispatchQueue.main.async {
                isSettingUpMagnet = false
                switch result {
                case .success:
                    magnetSetupResult = "Success! Your magnet is ready."
                    if let householdId {
                        Task {
                            try? await APIService.shared.updateNfcConfigured(householdId: householdId)
                        }
                    }
                case .failure(let error):
                    magnetSetupResult = error.localizedDescription
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
    SettingsView()
        .environment(AuthService())
}
