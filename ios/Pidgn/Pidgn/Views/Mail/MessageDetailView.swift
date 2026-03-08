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
                VStack(alignment: .leading, spacing: 8) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(message.fromDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Divider()

                // Content based on message type
                switch message.type {
                case "photo":
                    photoContent
                case "voice":
                    voiceContent
                default:
                    textContent
                }

                Spacer(minLength: 20)

                // Metadata
                metadataSection
            }
            .padding(24)
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            audioPlayer?.pause()
        }
    }

    // MARK: - Text Content

    private var textContent: some View {
        Text(message.content)
            .font(.body)
            .lineSpacing(4)
    }

    // MARK: - Photo Content

    private var photoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.body)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Voice Content

    private var voiceContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Voice Memo")
                .font(.headline)

            Button {
                togglePlayback()
            } label: {
                Label(
                    isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.title2)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Metadata

    private var metadataSection: some View {
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

    // MARK: - Audio Playback

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            guard let urlString = message.mediaUrl, let url = URL(string: urlString) else { return }

            if audioPlayer == nil {
                audioPlayer = AVPlayer(url: url)
            }
            audioPlayer?.play()
            isPlaying = true

            // Reset when done
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

    // MARK: - Date Formatting

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
            content: "Hope you're having a great day!",
            mediaUrl: nil,
            sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: false,
            openedAt: nil,
            openedByUserId: nil
        ))
    }
}
