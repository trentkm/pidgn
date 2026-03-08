//
//  MessageDetailView.swift
//  Pidgn
//
//  Full message detail screen.

import SwiftUI

struct MessageDetailView: View {
    let message: APIService.MailMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.fromDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Divider()

                // Message content
                Text(message.content)
                    .font(.body)
                    .lineSpacing(4)

                Spacer(minLength: 20)

                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    if let sentAt = message.sentAt {
                        HStack {
                            Text("Sent")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedFullDate(sentAt))
                        }
                        .font(.caption)
                    }

                    if message.isOpened, let openedAt = message.openedAt {
                        HStack {
                            Text("Opened")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedFullDate(openedAt))
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedFullDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: isoString) ?? {
            isoFormatter.formatOptions = [.withInternetDateTime]
            return isoFormatter.date(from: isoString)
        }() else { return isoString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        MessageDetailView(message: APIService.MailMessage(
            id: "1",
            fromUserId: "user1",
            fromDisplayName: "Mom",
            fromHouseholdId: "hh1",
            type: "text",
            content: "Hope you're having a great day! Don't forget to call grandma this weekend.",
            mediaUrl: nil,
            sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: false,
            openedAt: nil,
            openedByUserId: nil
        ))
    }
}
