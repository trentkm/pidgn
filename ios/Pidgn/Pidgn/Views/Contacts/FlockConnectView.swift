//
//  FlockConnectView.swift
//  Pidgn
//
//  "Connect with this nest?" — shown when the user taps a flock link.

import SwiftUI

struct FlockConnectView: View {
    @Environment(AuthService.self) var authService
    let targetHouseholdId: String
    let onDismiss: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var connectedName: String?

    private let bgColor = Color(red: 0.07, green: 0.06, blue: 0.05)
    private let cardBg = Color(red: 0.99, green: 0.96, blue: 0.93)

    private var noHousehold: Bool {
        authService.userProfile?.householdId == nil
    }

    private var isSameHousehold: Bool {
        authService.userProfile?.householdId == targetHouseholdId
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Warm glow + icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PidgnTheme.accent.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)

                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(PidgnTheme.accent.opacity(0.12))
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(PidgnTheme.accent.opacity(0.2), lineWidth: 1)
                            )

                        Image(systemName: "bird.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(PidgnTheme.accent)
                    }
                }

                // Text
                VStack(spacing: 8) {
                    if let name = connectedName {
                        Text("Request sent to \(name)!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)
                            .multilineTextAlignment(.center)

                        Text("They'll need to accept before\nyou can exchange letters.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    } else if noHousehold {
                        Text("Set up your Nest first")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)

                        Text("You need a nest before you can\nconnect with other households.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    } else if isSameHousehold {
                        Text("That's your own Nest!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)

                        Text("You can't connect with yourself.\nShare this link with another family.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Connect with\nthis household?")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)
                            .multilineTextAlignment(.center)

                        Text("Add them to your flock so you\ncan exchange letters.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if connectedName != nil {
                        Button {
                            onDismiss()
                        } label: {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    PidgnTheme.accent,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                        }
                    } else if noHousehold || isSameHousehold {
                        Button {
                            onDismiss()
                        } label: {
                            Text("Got it")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    PidgnTheme.accent,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                        }
                    } else {
                        Button {
                            Task { await sendRequest() }
                        } label: {
                            if isConnecting {
                                ProgressView()
                                    .tint(bgColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        PidgnTheme.accent,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                            } else {
                                Text("Connect")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(bgColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        PidgnTheme.accent,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                            }
                        }
                        .disabled(isConnecting)

                        Button {
                            onDismiss()
                        } label: {
                            Text("Not now")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    private func sendRequest() async {
        isConnecting = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.connectToHousehold(targetHouseholdId: targetHouseholdId)
            connectedName = response.targetHouseholdName
        } catch {
            errorMessage = error.localizedDescription
        }

        isConnecting = false
    }
}

#Preview {
    FlockConnectView(targetHouseholdId: "abc123", onDismiss: {})
        .environment(AuthService())
}
