//
//  MessageRevealView.swift
//  Pidgn
//
//  The core product moment. A sealed letter breaks open.
//  Warm, magical, unhurried — like candlelight.

import SwiftUI

struct MessageRevealView: View {
    let message: APIService.MailMessage
    let onDismiss: () -> Void

    @State private var envelopeOpened = false
    @State private var showContent = false
    @State private var showDone = false

    private let bgColor = Color(red: 0.12, green: 0.10, blue: 0.08)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Envelope phase
                if !showContent {
                    VStack(spacing: 24) {
                        // Envelope with seal
                        ZStack {
                            // Glow behind envelope
                            Circle()
                                .fill(PidgnTheme.accent.opacity(envelopeOpened ? 0.15 : 0.05))
                                .frame(width: 200, height: 200)
                                .blur(radius: 40)

                            // Envelope body
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PidgnTheme.sand)
                                .frame(width: 180, height: 120)
                                .shadow(color: PidgnTheme.accent.opacity(0.2), radius: 20)

                            // Seal / opened icon
                            Image(systemName: envelopeOpened ? "envelope.open.fill" : "seal.fill")
                                .font(.system(size: envelopeOpened ? 52 : 36))
                                .foregroundStyle(PidgnTheme.accent)
                                .scaleEffect(envelopeOpened ? 1.1 : 1.0)
                        }

                        if envelopeOpened {
                            VStack(spacing: 4) {
                                Text("From \(message.fromDisplayName)")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand)

                                Text("Opening your letter...")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand.opacity(0.4))
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // Content phase
                if showContent {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // From label
                            VStack(spacing: 4) {
                                Text("From")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand.opacity(0.35))
                                    .textCase(.uppercase)
                                    .tracking(2)

                                Text(message.fromDisplayName)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand)
                            }
                            .padding(.top, 40)

                            // Divider
                            Rectangle()
                                .fill(PidgnTheme.sand.opacity(0.1))
                                .frame(width: 40, height: 1)

                            // Content
                            revealContent
                                .padding(.horizontal, 8)

                            // Date
                            if let sentAt = message.sentAt {
                                Text(formattedDate(sentAt))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand.opacity(0.25))
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Done button
                if showDone {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(bgColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(PidgnTheme.sand, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear { startAnimation() }
    }

    @ViewBuilder
    private var revealContent: some View {
        switch message.type {
        case "photo":
            VStack(spacing: 12) {
                if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } placeholder: {
                        ProgressView().tint(PidgnTheme.sand)
                    }
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(PidgnTheme.sand.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
        case "voice":
            VStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundStyle(PidgnTheme.accent)
                Text("Voice note — open to listen")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(PidgnTheme.sand.opacity(0.5))
            }
        default:
            Text(message.content)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(PidgnTheme.sand)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
        }
    }

    private func startAnimation() {
        // Seal opens
        withAnimation(.easeInOut(duration: 0.7).delay(0.6)) {
            envelopeOpened = true
        }
        // Content fades in
        withAnimation(.easeInOut(duration: 0.6).delay(1.8)) {
            showContent = true
        }
        // Done button slides up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(2.5)) {
            showDone = true
        }
    }

    private func formattedDate(_ isoString: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: isoString) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: isoString)
        }() else { return "" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MessageRevealView(
        message: APIService.MailMessage(
            id: "1", fromUserId: "user1", fromDisplayName: "Mom",
            fromHouseholdId: "hh1", type: "text",
            content: "Hope you're having a great day! Don't forget to call grandma.",
            mediaUrl: nil, sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: true, openedAt: "2026-03-07T14:00:00.000Z",
            openedByUserId: "user2"
        ),
        onDismiss: {}
    )
}
