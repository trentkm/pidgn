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

    @State private var sealBroken = false
    @State private var envelopeOpened = false
    @State private var showContent = false
    @State private var showDone = false

    private let bgColor = Color(red: 0.11, green: 0.09, blue: 0.07)

    private var mood: Stationery {
        Stationery(rawValue: message.stationery ?? "parchment") ?? .parchment
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Envelope phase
                if !showContent {
                    VStack(spacing: 28) {
                        ZStack {
                            // Warm glow — tinted to stationery accent
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            mood.accentColor.opacity(envelopeOpened ? 0.2 : 0.04),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 140
                                    )
                                )
                                .frame(width: 280, height: 280)

                            // Envelope card — uses stationery gradient
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(mood.paperGradient)
                                .frame(width: 200, height: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: mood.accentColor.opacity(0.25), radius: 30, y: 8)
                                .scaleEffect(envelopeOpened ? 1.05 : 1.0)

                            // Seal that breaks
                            ZStack {
                                Circle()
                                    .fill(PidgnTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: PidgnTheme.accent.opacity(0.4), radius: 12)

                                Image(systemName: "seal.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(sealBroken ? 1.6 : 1.0)
                            .opacity(sealBroken ? 0 : 1.0)
                            .rotationEffect(.degrees(sealBroken ? 15 : 0))
                        }

                        if envelopeOpened {
                            VStack(spacing: 6) {
                                Text("From \(message.fromDisplayName)")
                                    .font(.system(size: 19, weight: .medium, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand)

                                Text("Opening your letter...")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(PidgnTheme.sand.opacity(0.35))
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                // Content phase — stationery paper
                if showContent {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Paper card with stationery background
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(mood.paperGradient)

                                // Ruled lines (for text/default)
                                if message.type != "photo" {
                                    VStack(spacing: 0) {
                                        ForEach(0..<8, id: \.self) { _ in
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
                                    .padding(.top, 80)
                                }

                                VStack(spacing: 16) {
                                    // From header with crest
                                    VStack(spacing: 4) {
                                        if let crestEmoji = NestCrest(rawValue: message.fromCrest ?? "")?.emoji {
                                            Text(crestEmoji)
                                                .font(.system(size: 28))
                                        }

                                        Text("From")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(mood.textColor.opacity(0.35))
                                            .textCase(.uppercase)
                                            .tracking(2.5)

                                        Text(message.fromDisplayName)
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
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

                                    // Message content
                                    revealContent
                                        .padding(.horizontal, 20)

                                    // Timestamp
                                    if let sentAt = message.sentAt {
                                        Text(formattedDate(sentAt))
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(mood.textColor.opacity(0.25))
                                            .padding(.top, 8)
                                    }

                                    Spacer(minLength: 24)
                                }
                                .padding(.bottom, 8)
                            }
                            .frame(minHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: mood.accentColor.opacity(0.15), radius: 20, y: 8)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
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
                            .background(
                                PidgnTheme.sand,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: sealBroken)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: showContent)
        .onAppear { startAnimation() }
    }

    @ViewBuilder
    private var revealContent: some View {
        switch message.type {
        case "photo":
            VStack(spacing: 14) {
                if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } placeholder: {
                        ProgressView().tint(mood.accentColor)
                    }
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.custom("Bradley Hand", size: 16))
                        .foregroundStyle(mood.textColor.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
        case "voice":
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundStyle(mood.accentColor)
                Text("Voice note — open to listen")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(mood.textColor.opacity(0.45))
            }
        default:
            Text(message.content)
                .font(.custom("Bradley Hand", size: 22))
                .foregroundStyle(mood.textColor)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
        }
    }

    private func startAnimation() {
        withAnimation(.spring(.bouncy, blendDuration: 0.3).delay(0.5)) {
            sealBroken = true
        }
        withAnimation(.easeInOut(duration: 0.6).delay(0.8)) {
            envelopeOpened = true
        }
        withAnimation(.easeInOut(duration: 0.5).delay(2.0)) {
            showContent = true
        }
        withAnimation(.spring(.snappy).delay(2.6)) {
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
            fromHouseholdId: "hh1", fromPlumage: "sage", fromCrest: "dove",
            type: "text",
            content: "Hope you're having a great day! Don't forget to call grandma.",
            mediaUrl: nil, stationery: "rosewater",
            sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: true, openedAt: "2026-03-07T14:00:00.000Z",
            openedByUserId: "user2"
        ),
        onDismiss: {}
    )
}
