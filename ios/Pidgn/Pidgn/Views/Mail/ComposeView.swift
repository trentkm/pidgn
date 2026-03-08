//
//  ComposeView.swift
//  Pidgn
//
//  Compose and send a text message to a connected household.

import SwiftUI

struct ComposeView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) var dismiss

    @State private var contacts: [Contact] = []
    @State private var selectedContact: Contact?
    @State private var messageText = ""
    @State private var isLoadingContacts = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSentConfirmation = false

    struct Contact: Identifiable, Hashable {
        let id: String // householdId
        let name: String
    }

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    var body: some View {
        Form {
            // Recipient picker
            Section("To") {
                if isLoadingContacts {
                    ProgressView()
                } else if contacts.isEmpty {
                    Text("No connected households yet")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Recipient", selection: $selectedContact) {
                        Text("Select a household").tag(nil as Contact?)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(contact as Contact?)
                        }
                    }
                }
            }

            // Message body
            Section("Message") {
                TextEditor(text: $messageText)
                    .frame(minHeight: 150)

                HStack {
                    Spacer()
                    Text("\(messageText.count)/500")
                        .font(.caption)
                        .foregroundStyle(messageText.count > 500 ? .red : .secondary)
                }
            }

            // Error
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Compose")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await sendMessage() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("Send")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(selectedContact == nil || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messageText.count > 500 || isSending)
            }
        }
        .task {
            await loadContacts()
        }
        .alert("Mail Sent!", isPresented: $showSentConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your message has been delivered.")
        }
    }

    private func loadContacts() async {
        guard let householdId else { return }
        isLoadingContacts = true

        do {
            let response = try await APIService.shared.fetchContacts(householdId: householdId)
            contacts = response.contacts
                .filter { $0.status == "accepted" }
                .map { Contact(id: $0.householdId, name: $0.householdName) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingContacts = false
    }

    private func sendMessage() async {
        guard let contact = selectedContact else { return }
        isSending = true
        errorMessage = nil

        do {
            _ = try await APIService.shared.sendMail(
                targetHouseholdId: contact.id,
                content: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showSentConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}

#Preview {
    NavigationStack {
        ComposeView()
            .environment(AuthService())
    }
}
