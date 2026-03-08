//
//  MessageRevealView.swift
//  Pidgn
//
//  Envelope-opening animation when a message is revealed via NFC tap.

import SwiftUI

struct MessageRevealView: View {
    let message: APIService.MailMessage
    let onDismiss: () -> Void

    @State private var envelopeOpened = false
    @State private var contentRevealed = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Envelope animation
                ZStack {
                    // Envelope body
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 200, height: 140)
                        .shadow(color: .white.opacity(0.2), radius: 20)

                    // Envelope flap
                    Triangle()
                        .fill(envelopeOpened ? Color.white.opacity(0.3) : Color.white.opacity(0.9))
                        .frame(width: 200, height: 80)
                        .offset(y: -70)
                        .rotation3DEffect(
                            .degrees(envelopeOpened ? -180 : 0),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .bottom
                        )

                    // Envelope icon
                    Image(systemName: envelopeOpened ? "envelope.open.fill" : "envelope.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                        .scaleEffect(envelopeOpened ? 1.2 : 1.0)
                }
                .opacity(showContent ? 0 : 1)
                .scaleEffect(showContent ? 0.5 : 1.0)

                // "From" label during animation
                if envelopeOpened && !showContent {
                    Text("From \(message.fromDisplayName)")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .transition(.opacity)
                }

                // Message content
                if showContent {
                    VStack(spacing: 16) {
                        Text("From \(message.fromDisplayName)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(message.content)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 32)

                        if let sentAt = message.sentAt {
                            Text(formattedDate(sentAt))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer()

                if showContent {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Step 1: Open the envelope flap
        withAnimation(.easeInOut(duration: 0.6).delay(0.5)) {
            envelopeOpened = true
        }

        // Step 2: Transition to content
        withAnimation(.easeInOut(duration: 0.5).delay(1.5)) {
            showContent = true
        }
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else { return "" }
            return formatDisplay(date)
        }
        return formatDisplay(date)
    }

    private func formatDisplay(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - Triangle Shape for envelope flap

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
            id: "1",
            fromUserId: "user1",
            fromDisplayName: "Mom",
            fromHouseholdId: "hh1",
            type: "text",
            content: "Hope you're having a great day! Don't forget to call grandma this weekend.",
            mediaUrl: nil,
            sentAt: "2026-03-07T12:00:00.000Z",
            isOpened: true,
            openedAt: "2026-03-07T14:00:00.000Z",
            openedByUserId: "user2"
        ),
        onDismiss: {}
    )
}
