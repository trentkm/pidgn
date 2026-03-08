//
//  ContactsView.swift
//  Pidgn
//
//  Your flock — the households you're connected with.

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
                    VStack(spacing: 16) {
                        Image(systemName: "bird.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(PidgnTheme.accent)
                            .symbolEffect(.pulse)
                        Text("Gathering your flock...")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else if let error = errorMessage, contacts.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't find the flock", systemImage: "bird")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await fetchContacts() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PidgnTheme.accent)
                    }
                } else if contacts.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(PidgnTheme.sand)
                                .frame(width: 120, height: 120)

                            Image(systemName: "bird.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(PidgnTheme.accent.opacity(0.6))
                        }

                        VStack(spacing: 6) {
                            Text("No flock yet")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                            Text("Connect with another household\nto start sending letters back and forth.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            showAddConnection = true
                        } label: {
                            Label("Grow Your Flock", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PidgnTheme.accent)
                        .padding(.top, 8)

                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    List {
                        if !incomingRequests.isEmpty {
                            Section {
                                ForEach(incomingRequests) { contact in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.householdName)
                                                .font(.system(.body, design: .rounded, weight: .medium))
                                            Text("Wants to join your flock")
                                                .font(.system(size: 13, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Welcome In") {
                                            Task { await acceptRequest(fromHouseholdId: contact.householdId) }
                                        }
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .tint(PidgnTheme.sage)
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(PidgnTheme.accent)
                                    Text("Knocking at the Door")
                                }
                            }
                        }

                        if !acceptedContacts.isEmpty {
                            Section("Your Flock") {
                                ForEach(acceptedContacts) { contact in
                                    HStack(spacing: 10) {
                                        Text(String(contact.householdName.prefix(1)).uppercased())
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(PidgnTheme.accent, in: Circle())

                                        Text(contact.householdName)
                                            .font(.system(.body, design: .rounded))
                                    }
                                }
                            }
                        }

                        if !outgoingRequests.isEmpty {
                            Section("On the Wing") {
                                ForEach(outgoingRequests) { contact in
                                    HStack {
                                        Text(contact.householdName)
                                            .font(.system(.body, design: .rounded))
                                        Spacer()
                                        Text("Waiting...")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Flock")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddConnection = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(PidgnTheme.accent)
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

#Preview {
    ContactsView()
        .environment(AuthService())
}
