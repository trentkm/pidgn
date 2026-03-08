//
//  MessageDetailView.swift
//  Pidgn
//
//  Full message detail screen — supports text, photo, and voice messages.

import SwiftUI
import AVFoundation

struct MessageDetailView: View {
    let message: APIService.MailMessage
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.fromDisplayName)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }

                Divider()

                // Content
                switch message.type {
                case "photo":
                    photoContent
                case "voice":
                    voiceContent
                default:
                    Text(message.content)
                        .font(.system(size: 17, design: .rounded))
                        .lineSpacing(5)
                }

                Spacer(minLength: 20)
                metadataSection
            }
            .padding(24)
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { audioPlayer?.pause() }
    }

    private var photoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } placeholder: {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                }
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.system(size: 17, design: .rounded))
                    .lineSpacing(4)
            }
        }
    }

    private var voiceContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 36))
                .foregroundStyle(PidgnTheme.accent)

            Text("Voice Note")
                .font(.system(.headline, design: .rounded))

            Button {
                togglePlayback()
            } label: {
                Label(
                    isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.title2)
            }
            .tint(PidgnTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let sentAt = message.sentAt {
                HStack {
                    Text("Sent").foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedFullDate(sentAt))
                }
                .font(.caption)
            }

            if message.isOpened, let openedAt = message.openedAt {
                HStack {
                    Text("Opened").foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedFullDate(openedAt))
                }
                .font(.caption)
            }
        }
        .padding(14)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            guard let urlString = message.mediaUrl, let url = URL(string: urlString) else { return }
            if audioPlayer == nil { audioPlayer = AVPlayer(url: url) }
            audioPlayer?.play()
            isPlaying = true

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: audioPlayer?.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                audioPlayer?.seek(to: .zero)
            }
        }
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
            id: "1", fromUserId: "user1", fromDisplayName: "Mom",
            fromHouseholdId: "hh1", type: "text",
            content: "Hope you're having a great day!",
            mediaUrl: nil, sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: false, openedAt: nil, openedByUserId: nil
        ))
    }
}
