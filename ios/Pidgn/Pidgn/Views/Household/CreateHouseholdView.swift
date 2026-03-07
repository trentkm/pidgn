//
//  CreateHouseholdView.swift
//  Pidgn
//

import SwiftUI

struct CreateHouseholdView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss
    @State private var householdName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Name Your Household")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("This is how other families will see you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("e.g. The Morrells", text: $householdName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await createHousehold()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Household")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(householdName.isEmpty || isLoading)

            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationTitle("Create Household")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func createHousehold() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await APIService.shared.createHousehold(name: householdName)
            await authService.refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        CreateHouseholdView()
            .environment(AuthService())
    }
}
