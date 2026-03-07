//
//  JoinHouseholdView.swift
//  Pidgn
//

import SwiftUI

struct JoinHouseholdView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Join a Household")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Enter the invite code from a family member.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Invite Code", text: $inviteCode)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await joinHousehold()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join Household")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(inviteCode.isEmpty || isLoading)

            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationTitle("Join Household")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func joinHousehold() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await APIService.shared.joinHousehold(inviteCode: inviteCode)
            await authService.refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        JoinHouseholdView()
            .environmentObject(AuthService())
    }
}
