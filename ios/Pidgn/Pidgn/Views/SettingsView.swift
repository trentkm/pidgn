//
//  SettingsView.swift
//  Pidgn
//
//  Your nest — identity card, plumage & crest customization, household settings.

import SwiftUI
import UIKit
import PhotosUI
import FirebaseAuth
import FirebaseStorage

// MARK: - Nest Customization Data

enum NestColor: String, CaseIterable {
    case terracotta, sage, slate, plum, midnight, ember

    var color: Color {
        switch self {
        case .terracotta: Color(red: 0.76, green: 0.48, blue: 0.35)
        case .sage:       Color(red: 0.48, green: 0.55, blue: 0.44)
        case .slate:      Color(red: 0.44, green: 0.50, blue: 0.66)
        case .plum:       Color(red: 0.66, green: 0.48, blue: 0.62)
        case .midnight:   Color(red: 0.35, green: 0.35, blue: 0.54)
        case .ember:      Color(red: 0.72, green: 0.36, blue: 0.29)
        }
    }

    var displayName: String {
        switch self {
        case .terracotta: "Terracotta"
        case .sage:       "Sage"
        case .slate:      "Slate"
        case .plum:       "Plum"
        case .midnight:   "Midnight"
        case .ember:      "Ember"
        }
    }
}

enum NestCrest: String, CaseIterable {
    case dove, owl, robin, swan, eagle, feather

    var emoji: String {
        switch self {
        case .dove:    "🕊️"
        case .owl:     "🦉"
        case .robin:   "🐦"
        case .swan:    "🦢"
        case .eagle:   "🦅"
        case .feather: "🪶"
        }
    }

    var displayName: String {
        switch self {
        case .dove:    "Dove"
        case .owl:     "Owl"
        case .robin:   "Robin"
        case .swan:    "Swan"
        case .eagle:   "Eagle"
        case .feather: "Feather"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AuthService.self) var authService
    @State private var inviteCode: String?
    @State private var inviteURL: String?
    @State private var isGeneratingInvite = false
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var copiedHouseholdId = false
    @State private var isSettingUpMagnet = false
    @State private var magnetSetupResult: String?
    @State private var settingsOpen = false

    // Customization (synced with Firestore)
    @State private var plumageRaw: String = NestColor.terracotta.rawValue
    @State private var crestRaw: String = NestCrest.dove.rawValue
    @State private var bio: String = ""
    @State private var editingBio = false
    @State private var profileLoaded = false
    @State private var stats: APIService.UserStats?
    @State private var avatarUrl: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    private var plumage: NestColor {
        NestColor(rawValue: plumageRaw) ?? .terracotta
    }

    private var crest: NestCrest {
        NestCrest(rawValue: crestRaw) ?? .dove
    }

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private let bgColor = Color(red: 0.07, green: 0.06, blue: 0.05)
    private let cardBg = Color(red: 0.99, green: 0.96, blue: 0.93) // FDF5ED

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    identityCard
                    customizeSection
                    nestSettingsSection
                    Spacer(minLength: 20)
                }
            }
        }
        .navigationTitle("Nest")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            loadProfileIfNeeded()
            Task { stats = try? await APIService.shared.fetchStats() }
        }
        .onChange(of: plumageRaw) { _, newValue in
            guard profileLoaded else { return }
            Task { try? await APIService.shared.updateProfile(plumage: newValue) }
        }
        .onChange(of: crestRaw) { _, newValue in
            guard profileLoaded else { return }
            Task { try? await APIService.shared.updateProfile(crest: newValue) }
        }
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        VStack(spacing: 0) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                cardBg.opacity(0.07),
                                cardBg.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(cardBg.opacity(0.06), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    // Avatar — tap to change photo
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(
                                avatarUrl: avatarUrl,
                                plumage: plumageRaw,
                                crest: crestRaw,
                                displayName: authService.userProfile?.displayName ?? "",
                                size: 80,
                                cornerRadius: 24
                            )
                            .shadow(color: plumage.color.opacity(0.4), radius: 12, y: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            )

                            if isUploadingAvatar {
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .offset(x: 4, y: 4)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(PidgnTheme.accent))
                                    .overlay(Circle().stroke(Color(red: 0.07, green: 0.06, blue: 0.05), lineWidth: 2))
                                    .offset(x: 4, y: 4)
                            }
                        }
                    }
                    .disabled(isUploadingAvatar)
                    .onChange(of: selectedPhoto) { _, newItem in
                        guard let newItem else { return }
                        Task { await uploadAvatar(item: newItem) }
                    }
                    .padding(.top, 28)

                    // Name
                    Text(authService.userProfile?.displayName ?? "")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(cardBg)
                        .padding(.top, 14)

                    // Bio
                    if editingBio {
                        TextField("your bio", text: $bio)
                            .font(.custom("Bradley Hand", size: 16))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(PidgnTheme.accent.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .frame(maxWidth: 240)
                            .onSubmit { saveBio() }
                            .padding(.top, 10)
                    } else {
                        Text("\"\(bio)\"")
                            .font(.custom("Bradley Hand", size: 16))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                            .onTapGesture { editingBio = true }
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.horizontal, 40)
                                    .offset(y: 4)
                            }
                    }

                    // Stats
                    HStack(spacing: 0) {
                        statItem(value: stats.map { "\($0.lettersSent)" } ?? "—", label: "Letters sent")
                        statDivider
                        statItem(value: stats.map { "\($0.lettersReceived)" } ?? "—", label: "Letters received")
                        statDivider
                        statItem(value: stats.map { "\($0.flockMembers)" } ?? "—", label: "Flock members")
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(cardBg)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.25))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    // MARK: - Customize Section

    private var customizeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            customizeSectionHeader
            plumageCard
                .padding(.bottom, 12)
            crestCard
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private var customizeSectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 12))
                .foregroundStyle(PidgnTheme.accent)

            Text("Customize your nest")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(1)
        }
        .padding(.bottom, 16)
    }

    private func plumageButton(for color: NestColor) -> some View {
        let isSelected = plumage == color
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                plumageRaw = color.rawValue
            }
        } label: {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.color, color.color.opacity(0.73)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 44)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.4) : Color.clear, lineWidth: 2.5)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .shadow(
                    color: isSelected ? color.color.opacity(0.5) : Color.black.opacity(0.15),
                    radius: isSelected ? 8 : 3,
                    y: isSelected ? 4 : 2
                )
        }
        .buttonStyle(.plain)
    }

    private var plumageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plumage")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(NestColor.allCases, id: \.self) { color in
                    plumageButton(for: color)
                }
            }

            Text("\(plumage.displayName) — visible on your letters")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.15))
                .italic()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func crestButton(for c: NestCrest) -> some View {
        let isSelected = crest == c
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                crestRaw = c.rawValue
            }
        } label: {
            VStack(spacing: 1) {
                Text(c.emoji)
                    .font(.system(size: 22))
                Text(c.displayName)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.2))
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? cardBg.opacity(0.08) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? PidgnTheme.accent.opacity(0.3) : Color.white.opacity(0.04),
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .offset(y: isSelected ? -2 : 0)
        }
        .buttonStyle(.plain)
    }

    private var crestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crest")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(NestCrest.allCases, id: \.self) { c in
                    crestButton(for: c)
                }
            }

            Text("Your crest appears on your seal")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.15))
                .italic()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    // MARK: - Nest Settings (Collapsible)

    private var nestSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    settingsOpen.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.25))

                        Text("Nest Settings")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .textCase(.uppercase)
                            .tracking(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .rotationEffect(.degrees(settingsOpen ? 180 : 0))
                }
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)

            if settingsOpen {
                VStack(spacing: 8) {
                    // Nest ID
                    if let householdId {
                        nestIdCard(householdId: householdId)
                    }

                    // Invite
                    inviteCard

                    // Fridge Magnet
                    magnetCard

                    // Account
                    accountCard

                    // Sign Out
                    signOutButton
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Settings Cards

    private func nestIdCard(householdId: String) -> some View {
        Button {
            UIPasteboard.general.string = householdId
            withAnimation { copiedHouseholdId = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { copiedHouseholdId = false }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nest ID")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack {
                    Text(copiedHouseholdId ? "Copied!" : householdId)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(
                            copiedHouseholdId ? PidgnTheme.sage : Color.white.opacity(0.5)
                        )
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: copiedHouseholdId ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            copiedHouseholdId ? PidgnTheme.sage : Color.white.opacity(0.3)
                        )
                }

                Text("Share with family so they can find your nest")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.15))
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var inviteCard: some View {
        VStack(spacing: 0) {
            Button {
                Task { await generateInvite() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PidgnTheme.accent.opacity(0.1))
                            .frame(width: 36, height: 36)

                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(PidgnTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Invite to the Nest")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PidgnTheme.accent)

                        Text("Send a link to invite someone to your nest")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.2))
                    }

                    Spacer()

                    if isGeneratingInvite {
                        ProgressView()
                            .tint(PidgnTheme.accent)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingInvite)
            .sheet(isPresented: $showShareSheet) {
                if let url = inviteURL {
                    ShareSheet(items: [
                        "Join my Nest on Pidgn! \(url)" as Any
                    ])
                    .presentationDetents([.medium])
                }
            }
        }
    }

    private var magnetCard: some View {
        VStack(spacing: 0) {
            Button {
                setupMagnet()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(PidgnTheme.accent.opacity(0.1))
                            .frame(width: 36, height: 36)

                        Image(systemName: "wave.3.right")
                            .font(.system(size: 16))
                            .foregroundStyle(PidgnTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fridge Magnet")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PidgnTheme.accent)

                        Text("Program an NFC tag to open sealed letters")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.2))
                    }

                    Spacer()

                    if isSettingUpMagnet {
                        ProgressView()
                            .tint(PidgnTheme.accent)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isSettingUpMagnet)

            if let result = magnetSetupResult {
                HStack(spacing: 8) {
                    Image(systemName: result.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(result)
                }
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(result.contains("Success") ? PidgnTheme.sage : .red)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
                .padding(.top, 4)
            }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Account")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.25))
                .textCase(.uppercase)
                .tracking(0.5)

            Text(authService.userProfile?.email ?? "")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private var signOutButton: some View {
        Button {
            authService.signOut()
        } label: {
            Text("Sign Out")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.78, green: 0.31, blue: 0.27).opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.78, green: 0.31, blue: 0.27).opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(red: 0.78, green: 0.31, blue: 0.27).opacity(0.1), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // Error
    private var errorSection: some View {
        Group {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(16)
            }
        }
    }

    // MARK: - Profile Sync

    private func loadProfileIfNeeded() {
        guard !profileLoaded, let profile = authService.userProfile else { return }
        if let p = profile.plumage { plumageRaw = p }
        if let c = profile.crest { crestRaw = c }
        if let b = profile.bio { bio = b }
        avatarUrl = profile.avatarUrl
        profileLoaded = true
    }

    private func saveBio() {
        editingBio = false
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        bio = trimmed
        Task { try? await APIService.shared.updateProfile(bio: trimmed) }
    }

    // MARK: - Avatar Upload

    private func uploadAvatar(item: PhotosPickerItem) async {
        guard let uid = authService.user?.uid else { return }
        isUploadingAvatar = true

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                isUploadingAvatar = false
                return
            }

            // Compress to JPEG
            guard let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.7) else {
                isUploadingAvatar = false
                return
            }

            // Upload to Firebase Storage
            let storageRef = Storage.storage().reference().child("avatars/\(uid).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await storageRef.putDataAsync(jpegData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            let urlString = downloadURL.absoluteString

            // Save URL to profile
            try await APIService.shared.updateProfile(avatarUrl: urlString)
            avatarUrl = urlString
            await authService.refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploadingAvatar = false
        selectedPhoto = nil
    }

    // MARK: - Actions

    private func setupMagnet() {
        isSettingUpMagnet = true
        magnetSetupResult = nil

        NFCService.shared.writeTag { result in
            DispatchQueue.main.async {
                isSettingUpMagnet = false
                switch result {
                case .success:
                    magnetSetupResult = "Success! Your magnet is ready."
                    if let householdId {
                        Task {
                            try? await APIService.shared.updateNfcConfigured(householdId: householdId)
                        }
                    }
                case .failure(let error):
                    magnetSetupResult = error.localizedDescription
                }
            }
        }
    }

    private func generateInvite() async {
        guard let householdId else { return }
        isGeneratingInvite = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.generateInvite(householdId: householdId)
            inviteCode = response.inviteCode
            inviteURL = "https://pidgn.app/invite/\(response.inviteCode)"
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingInvite = false
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AuthService())
    }
}
