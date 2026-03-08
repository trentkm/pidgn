//
//  MailboxView.swift
//  Pidgn
//
//  Displays received messages sorted by date. Pull to refresh.

import SwiftUI

struct MailboxView: View {
    @Environment(AuthService.self) var authService
    @State private var messages: [APIService.MailMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasMore = false

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
                            NavigationLink(destination: MessageDetailView(message: message)) {
                                MessageRow(message: message)
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
}

// MARK: - Message Row

struct MessageRow: View {
    let message: APIService.MailMessage

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            Circle()
                .fill(message.isOpened ? Color.clear : Color.blue)
                .frame(width: 10, height: 10)

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
            // Try without fractional seconds
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

#Preview {
    MailboxView()
        .environment(AuthService())
}
