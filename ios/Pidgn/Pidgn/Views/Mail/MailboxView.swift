//
//  MailboxView.swift
//  Pidgn
//
//  Displays received messages. Unopened messages are locked — tap magnet to read.

import SwiftUI

struct MailboxView: View {
    @Environment(AuthService.self) var authService
    @State private var messages: [APIService.MailMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasMore = false
    @State private var openingMessage: APIService.MailMessage?
    @State private var revealedMessage: APIService.MailMessage?
    @State private var showReveal = false

    // Set by Universal Link handler to trigger opening all unread
    @State var shouldOpenUnread: Bool = false

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && messages.isEmpty {
                    ProgressView("Loading mail...")
                } else if messages.isEmpty {
                    ContentUnavailableView(
                        "No Mail Yet",
                        systemImage: "envelope.open",
                        description: Text("Messages from connected households will appear here.")
                    )
                } else {
                    List {
                        ForEach(messages) { message in
                            if message.isOpened {
                                NavigationLink(destination: MessageDetailView(message: message)) {
                                    MessageRow(message: message)
                                }
                            } else {
                                LockedMessageRow(message: message)
                            }
                        }

                        if hasMore {
                            Button("Load More") {
                                Task { await loadMore() }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.blue)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Mailbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ComposeView()) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .refreshable {
                await fetchMailbox()
            }
            .task {
                await fetchMailbox()
            }
            .onChange(of: shouldOpenUnread) { _, shouldOpen in
                if shouldOpen {
                    shouldOpenUnread = false
                    Task { await openAllUnread() }
                }
            }
            .sheet(isPresented: $showReveal) {
                if let msg = revealedMessage {
                    MessageRevealView(message: msg) {
                        showReveal = false
                        revealedMessage = nil
                    }
                }
            }
            .overlay {
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.red.cornerRadius(8))
                            .padding()
                    }
                }
            }
        }
    }

    private func fetchMailbox() async {
        guard let householdId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchMailbox(householdId: householdId)
            messages = response.messages
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMore() async {
        guard let householdId, let lastId = messages.last?.id else { return }

        do {
            let response = try await APIService.shared.fetchMailbox(
                householdId: householdId,
                startAfter: lastId
            )
            messages.append(contentsOf: response.messages)
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openAllUnread() async {
        guard let householdId else { return }

        let unreadMessages = messages.filter { !$0.isOpened }
        guard let firstUnread = unreadMessages.first else { return }

        // Open the first unread message and show the reveal animation
        do {
            let response = try await APIService.shared.openMail(
                messageId: firstUnread.id,
                householdId: householdId
            )
            revealedMessage = response.message
            showReveal = true

            // Mark remaining unread as opened in background
            for msg in unreadMessages.dropFirst() {
                _ = try? await APIService.shared.openMail(
                    messageId: msg.id,
                    householdId: householdId
                )
            }

            // Refresh mailbox
            await fetchMailbox()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Message Row (opened)

struct MessageRow: View {
    let message: APIService.MailMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.open.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.fromDisplayName)
                    .font(.headline)

                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let sentAt = message.sentAt {
                Text(formattedDate(sentAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else { return "" }
            return relativeFormat(date)
        }
        return relativeFormat(date)
    }

    private func relativeFormat(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Locked Message Row (unopened)

struct LockedMessageRow: View {
    let message: APIService.MailMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.fromDisplayName)
                    .font(.headline)

                Text("Tap magnet to read")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .italic()
            }

            Spacer()

            Image(systemName: "lock.fill")
                .foregroundStyle(.blue)
                .font(.caption)

            if let sentAt = message.sentAt {
                Text(formattedDate(sentAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else { return "" }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    MailboxView()
        .environment(AuthService())
}
