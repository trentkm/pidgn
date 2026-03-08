//
//  AddConnectionView.swift
//  Pidgn
//
//  Enter a household ID to send a connection request.
//  In a future iteration, this could use invite codes or QR scanning.

import SwiftUI

struct AddConnectionView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) var dismiss

    @State private var householdCode = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var connectedName: String?

    var body: some View {
        Form {
            Section {
                TextField("Household ID", text: $householdCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Connect to a Household")
            } footer: {
                Text("Ask the other household for their Household ID from Settings.")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Add Connection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await sendConnectionRequest() }
                } label: {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(householdCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
            }
        }
        .alert("Request Sent!", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            if let name = connectedName {
                Text("Connection request sent to \(name). They'll need to accept it.")
            } else {
                Text("Connection request sent. They'll need to accept it.")
            }
        }
    }

    private func sendConnectionRequest() async {
        let trimmed = householdCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.connectToHousehold(targetHouseholdId: trimmed)
            connectedName = response.targetHouseholdName
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isConnecting = false
    }
}

#Preview {
    NavigationStack {
        AddConnectionView()
            .environment(AuthService())
    }
}
