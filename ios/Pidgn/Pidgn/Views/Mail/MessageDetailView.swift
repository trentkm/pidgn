//
//  MessageDetailView.swift
//  Pidgn
//
//  Full message detail screen — supports text, photo, and voice messages.
//  Displays on the sender's chosen stationery.

import SwiftUI
import AVFoundation

struct MessageDetailView: View {
    let message: APIService.MailMessage
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false

    private var mood: Stationery {
        Stationery(rawValue: message.stationery ?? "parchment") ?? .parchment
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.05)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Paper card
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(mood.paperGradient)

                        // Ruled lines for text
                        if message.type != "photo" {
                            VStack(spacing: 0) {
                                ForEach(0..<10, id: \.self) { _ in
                                    Color.clear
                                        .frame(height: 30)
                                        .overlay(alignment: .bottom) {
                                            Rectangle()
                                                .fill(mood.lineColor)
                                                .frame(height: 1)
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 90)
                        }

                        VStack(spacing: 16) {
                            // Header
                            VStack(spacing: 4) {
                                Text("From")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(mood.textColor.opacity(0.35))
                                    .textCase(.uppercase)
                                    .tracking(2.5)

                                Text(message.fromDisplayName)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(mood.textColor)
                            }
                            .padding(.top, 28)

                            // Divider
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(mood.accentColor.opacity(0.2))
                                    .frame(width: 24, height: 1)
                                Circle()
                                    .fill(mood.accentColor.opacity(0.4))
                                    .frame(width: 4, height: 4)
                                Rectangle()
                                    .fill(mood.accentColor.opacity(0.2))
                                    .frame(width: 24, height: 1)
                            }

                            // Content
                            Group {
                                switch message.type {
                                case "photo":
                                    photoContent
                                case "voice":
                                    voiceContent
                                default:
                                    Text(message.content)
                                        .font(.custom("Bradley Hand", size: 20))
                                        .foregroundStyle(mood.textColor)
                                        .lineSpacing(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 20)

                            Spacer(minLength: 20)

                            // Metadata
                            metadataSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: mood.accentColor.opacity(0.15), radius: 20, y: 8)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { audioPlayer?.pause() }
    }

    private var photoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } placeholder: {
                    ProgressView()
                        .tint(mood.accentColor)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.custom("Bradley Hand", size: 16))
                    .foregroundStyle(mood.textColor.opacity(0.85))
                    .lineSpacing(4)
            }
        }
    }

    private var voiceContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 36))
                .foregroundStyle(mood.accentColor)

            Text("Voice Note")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(mood.textColor)

            Button {
                togglePlayback()
            } label: {
                Label(
                    isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.title2)
            }
            .tint(mood.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let sentAt = message.sentAt {
                HStack {
                    Text("Sent").foregroundStyle(mood.textColor.opacity(0.35))
                    Spacer()
                    Text(formattedFullDate(sentAt))
                        .foregroundStyle(mood.textColor.opacity(0.5))
                }
                .font(.system(size: 11, design: .rounded))
            }

            if message.isOpened, let openedAt = message.openedAt {
                HStack {
                    Text("Opened").foregroundStyle(mood.textColor.opacity(0.35))
                    Spacer()
                    Text(formattedFullDate(openedAt))
                        .foregroundStyle(mood.textColor.opacity(0.5))
                }
                .font(.system(size: 11, design: .rounded))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(mood.textColor.opacity(0.05))
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
            mediaUrl: nil, stationery: "rosewater",
            sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: false, openedAt: nil, openedByUserId: nil
        ))
    }
}
