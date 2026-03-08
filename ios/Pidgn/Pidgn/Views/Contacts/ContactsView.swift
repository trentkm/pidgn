//
//  ContactsView.swift
//  Pidgn
//
//  Shows connected households and pending requests.

import SwiftUI

struct ContactsView: View {
    @Environment(AuthService.self) var authService
    @State private var contacts: [APIService.ContactEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddConnection = false

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var acceptedContacts: [APIService.ContactEntry] {
        contacts.filter { $0.status == "accepted" }
    }

    private var incomingRequests: [APIService.ContactEntry] {
        contacts.filter { $0.status == "pending" && $0.direction == "incoming" }
    }

    private var outgoingRequests: [APIService.ContactEntry] {
        contacts.filter { $0.status == "pending" && $0.direction == "outgoing" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && contacts.isEmpty {
                    ProgressView("Loading contacts...")
                } else if contacts.isEmpty {
                    ContentUnavailableView(
                        "No Connections",
                        systemImage: "person.2",
                        description: Text("Connect with another household to start sending messages.")
                    )
                } else {
                    List {
                        // Incoming requests
                        if !incomingRequests.isEmpty {
                            Section("Pending Requests") {
                                ForEach(incomingRequests) { contact in
                                    IncomingRequestRow(
                                        contact: contact,
                                        onAccept: {
                                            Task { await acceptRequest(fromHouseholdId: contact.householdId) }
                                        }
                                    )
                                }
                            }
                        }

                        // Connected households
                        if !acceptedContacts.isEmpty {
                            Section("Connected") {
                                ForEach(acceptedContacts) { contact in
                                    HStack {
                                        Image(systemName: "house.fill")
                                            .foregroundStyle(.blue)
                                        Text(contact.householdName)
                                            .font(.body)
                                    }
                                }
                            }
                        }

                        // Outgoing pending
                        if !outgoingRequests.isEmpty {
                            Section("Sent Requests") {
                                ForEach(outgoingRequests) { contact in
                                    HStack {
                                        Text(contact.householdName)
                                        Spacer()
                                        Text("Pending")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddConnection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddConnection) {
                NavigationStack {
                    AddConnectionView()
                }
                .presentationDetents([.medium])
            }
            .refreshable {
                await fetchContacts()
            }
            .task {
                await fetchContacts()
            }
            .onChange(of: showAddConnection) { _, isShowing in
                if !isShowing {
                    Task { await fetchContacts() }
                }
            }
        }
    }

    private func fetchContacts() async {
        guard let householdId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchContacts(householdId: householdId)
            contacts = response.contacts
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func acceptRequest(fromHouseholdId: String) async {
        do {
            _ = try await APIService.shared.acceptConnection(fromHouseholdId: fromHouseholdId)
            await fetchContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Incoming Request Row

struct IncomingRequestRow: View {
    let contact: APIService.ContactEntry
    let onAccept: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(contact.householdName)
                    .font(.body)
                Text("Wants to connect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Accept", action: onAccept)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

#Preview {
    ContactsView()
        .environment(AuthService())
}
