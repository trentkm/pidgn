//
//  AddConnectionView.swift
//  Pidgn
//
//  Share your flock link or manually enter a household ID to connect.

import SwiftUI

struct AddConnectionView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) var dismiss

    @State private var householdCode = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var connectedName: String?
    @State private var showShareSheet = false
    @State private var showManualEntry = false

    private let bgColor = Color(red: 0.07, green: 0.06, blue: 0.05)
    private let cardBg = Color(red: 0.99, green: 0.96, blue: 0.93)

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var flockURL: String? {
        guard let id = householdId else { return nil }
        return "https://pidgn.app/flock/\(id)"
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(PidgnTheme.accent.opacity(0.08))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bird.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(PidgnTheme.accent)
                        }

                        Text("Grow Your Flock")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(cardBg)

                        Text("Share your flock link with another\nhousehold to start exchanging letters.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                    // Share link card
                    if let url = flockURL {
                        VStack(spacing: 14) {
                            Button {
                                showShareSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Share Your Flock Link")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    PidgnTheme.accent,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                            }

                            Text("They'll get a request to connect — once accepted, you can send letters back and forth.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.2))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        .sheet(isPresented: $showShareSheet) {
                            ShareSheet(items: [
                                "Join my flock on Pidgn! \(url)" as Any
                            ])
                            .presentationDetents([.medium])
                        }
                    }

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        Text("or")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.2))
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)

                    // Manual entry
                    VStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                showManualEntry.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14))
                                Text("Enter a Nest ID manually")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .rotationEffect(.degrees(showManualEntry ? 180 : 0))
                            }
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        if showManualEntry {
                            VStack(spacing: 12) {
                                TextField("Paste household ID", text: $householdCode)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(cardBg)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                    )

                                Button {
                                    Task { await sendConnectionRequest() }
                                } label: {
                                    if isConnecting {
                                        ProgressView()
                                            .tint(bgColor)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                PidgnTheme.accent.opacity(0.8),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            )
                                    } else {
                                        Text("Send Request")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(bgColor)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                PidgnTheme.accent.opacity(0.8),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            )
                                    }
                                }
                                .disabled(householdCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 32)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }
                }
            }
        }
        .navigationTitle("Grow Your Flock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .alert("Request sent!", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            if let name = connectedName {
                Text("A little bird is on its way to \(name). They'll need to accept.")
            } else {
                Text("A little bird is on its way. They'll need to accept.")
            }
        }
    }

    private func sendConnectionRequest() async {
        let trimmed = householdCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.connectToHousehold(targetHouseholdId: trimmed)
            connectedName = response.targetHouseholdName
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isConnecting = false
    }
}

#Preview {
    NavigationStack {
        AddConnectionView()
            .environment(AuthService())
    }
}
