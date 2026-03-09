//
//  InviteJoinView.swift
//  Pidgn
//
//  "You've been invited to a Nest" — shown when the user taps an invite link.

import SwiftUI

struct InviteJoinView: View {
    @Environment(AuthService.self) var authService
    let inviteCode: String
    let onDismiss: () -> Void

    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedName: String?

    private let bgColor = Color(red: 0.07, green: 0.06, blue: 0.05)
    private let cardBg = Color(red: 0.99, green: 0.96, blue: 0.93)

    private var alreadyInHousehold: Bool {
        authService.userProfile?.householdId != nil
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Warm glow
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

                        Image(systemName: "house.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(PidgnTheme.accent)
                    }
                }

                VStack(spacing: 8) {
                    if let name = joinedName {
                        Text("Welcome to \(name)!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)

                        Text("You're part of the nest now.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                    } else if alreadyInHousehold {
                        Text("You're already in a Nest")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)

                        Text("You'll need to leave your current\nnest before joining a new one.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("You've been invited\nto join a Nest")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)
                            .multilineTextAlignment(.center)

                        Text("A nest is your household — the home\nyour letters fly to and from.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 24)

                // Invite code display
                if joinedName == nil {
                    Text(inviteCode.uppercased())
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PidgnTheme.accent)
                        .tracking(4)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(PidgnTheme.accent.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(PidgnTheme.accent.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.top, 20)
                }

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
                    if let _ = joinedName {
                        // Success — continue to app
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
                    } else if alreadyInHousehold {
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
                            Task { await joinNest() }
                        } label: {
                            if isJoining {
                                ProgressView()
                                    .tint(bgColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        PidgnTheme.accent,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                            } else {
                                Text("Join this Nest")
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
                        .disabled(isJoining)

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

    private func joinNest() async {
        isJoining = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.joinHousehold(inviteCode: inviteCode)
            await authService.refreshProfile()
            joinedName = response.household.name
        } catch {
            errorMessage = error.localizedDescription
        }

        isJoining = false
    }
}

#Preview {
    InviteJoinView(inviteCode: "ABC123", onDismiss: {})
        .environment(AuthService())
}
