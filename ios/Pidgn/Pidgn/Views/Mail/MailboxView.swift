//
//  MailboxView.swift
//  Pidgn
//
//  The roost — where letters land.
//  Sealed letters stack like Apple Wallet passes with premium card design.

import SwiftUI
import CoreNFC

struct MailboxView: View {
    @Environment(AuthService.self) var authService
    @State private var messages: [APIService.MailMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasMore = false
    @State private var revealedMessage: APIService.MailMessage?
    @State private var showReveal = false

    @State var shouldOpenUnread: Bool = false

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var sealedMessages: [APIService.MailMessage] {
        messages.filter { !$0.isOpened }
    }

    private var openedMessages: [APIService.MailMessage] {
        messages.filter { $0.isOpened }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authService.userProfile?.displayName.components(separatedBy: " ").first ?? ""
        let prefix = if hour < 12 { "Good morning" }
                     else if hour < 17 { "Good afternoon" }
                     else { "Good evening" }
        return name.isEmpty ? prefix : "\(prefix), \(name)"
    }

    private var greetingSubtitle: String {
        let sealedCount = sealedMessages.count
        if messages.isEmpty {
            return "No letters today — quiet afternoon."
        } else if sealedCount == 0 {
            return "All caught up. Nothing sealed."
        } else if sealedCount == 1 {
            return "A letter is waiting for you."
        } else {
            return "\(sealedCount) letters are waiting to be opened."
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bird.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(PidgnTheme.accent)
                            .symbolEffect(.pulse)
                        Text("Checking the roost...")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else if let error = errorMessage, messages.isEmpty {
                    ContentUnavailableView {
                        Label("The pigeon got lost", systemImage: "bird")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await fetchMailbox() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PidgnTheme.accent)
                    }
                } else if messages.isEmpty {
                    emptyState
                } else {
                    mailContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ComposeView()) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(PidgnTheme.accent)
                    }
                }
            }
            .refreshable {
                await fetchMailbox()
            }
            .task {
                await fetchMailbox()
            }
            .onChange(of: shouldOpenUnread) { _, shouldOpen in
                if shouldOpen {
                    shouldOpenUnread = false
                    Task { await openAllUnread() }
                }
            }
            .sheet(isPresented: $showReveal) {
                if let msg = revealedMessage {
                    MessageRevealView(message: msg) {
                        showReveal = false
                        revealedMessage = nil
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let error = errorMessage, !messages.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.red, in: Capsule())
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation { errorMessage = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PidgnTheme.sand)
                    .frame(width: 120, height: 120)
                Image(systemName: "bird")
                    .font(.system(size: 44))
                    .foregroundStyle(PidgnTheme.accent.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text("The roost is quiet")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("When someone sends you a letter,\nit'll land right here.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink(destination: ComposeView()) {
                Label("Send the first letter", systemImage: "paperplane")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .buttonStyle(.borderedProminent)
            .tint(PidgnTheme.accent)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Mail Content

    private var mailContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Personal greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(greetingSubtitle)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)

                // Sealed letter stack
                if !sealedMessages.isEmpty {
                    LetterStack(messages: sealedMessages) { message in
                        Task { await openSingleMessage(message) }
                    }
                    .padding(.bottom, 28)
                }

                // Opened letters
                if !openedMessages.isEmpty {
                    VStack(spacing: 0) {
                        // Centered "Opened" divider with lines
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.5)
                            Text("Opened")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                        ForEach(openedMessages) { message in
                            NavigationLink(destination: MessageDetailView(message: message)) {
                                OpenedLetterCard(message: message)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.bottom, 16)
                }

                if hasMore {
                    Button("Load more letters") {
                        Task { await loadMore() }
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PidgnTheme.accent)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Data

    private func fetchMailbox() async {
        guard let householdId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchMailbox(householdId: householdId)
            withAnimation(.spring(.snappy)) {
                messages = response.messages
            }
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMore() async {
        guard let householdId, let lastId = messages.last?.id else { return }

        do {
            let response = try await APIService.shared.fetchMailbox(
                householdId: householdId,
                startAfter: lastId
            )
            withAnimation(.spring(.snappy)) {
                messages.append(contentsOf: response.messages)
            }
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Open Single Letter (tap card → NFC scan → reveal)

    private func openSingleMessage(_ message: APIService.MailMessage) async {
        guard let householdId else { return }

        // Step 1: NFC scan — verify the user has the magnet
        do {
            try await NFCService.shared.scanTag()
        } catch {
            // User cancelled or NFC busy — silently return so they can tap again
            let nfcError = error as? NFCReaderError
            if nfcError?.code == .readerSessionInvalidationErrorUserCanceled { return }
            if let nfcErr = error as? NFCError, nfcErr == .sessionBusy { return }
            errorMessage = error.localizedDescription
            return
        }

        // Step 2: Mark the letter as opened on the server
        do {
            let response = try await APIService.shared.openMail(
                messageId: message.id,
                householdId: householdId
            )
            revealedMessage = response.message
            showReveal = true
            await fetchMailbox()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Open All Unread (Universal Link bulk open)

    func openAllUnread() async {
        guard let householdId else { return }

        let unreadMessages = messages.filter { !$0.isOpened }
        guard let firstUnread = unreadMessages.first else { return }

        do {
            let response = try await APIService.shared.openMail(
                messageId: firstUnread.id,
                householdId: householdId
            )
            revealedMessage = response.message
            showReveal = true

            for msg in unreadMessages.dropFirst() {
                _ = try? await APIService.shared.openMail(
                    messageId: msg.id,
                    householdId: householdId
                )
            }

            await fetchMailbox()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Letter Stack (Apple Wallet style)

private struct LetterStack: View {
    let messages: [APIService.MailMessage]
    let onTapMessage: (APIService.MailMessage) -> Void
    @State private var isExpanded = false

    private let cardHeight: CGFloat = 160
    private let collapsedPeek: CGFloat = 52
    private let expandedSpacing: CGFloat = 14

    private var collapsedHeight: CGFloat {
        if messages.count <= 1 { return cardHeight }
        return cardHeight + CGFloat(messages.count - 1) * collapsedPeek
    }

    private var expandedHeight: CGFloat {
        CGFloat(messages.count) * cardHeight + CGFloat(messages.count - 1) * expandedSpacing
    }

    // Subtle rotation per card for a natural "pile of mail" feel
    private static let rotations: [Double] = [0, -1.0, 0.7, -0.4, 0.9, -0.6]

    @State private var tappedMessageId: String?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    SealedLetterCard(
                        message: message,
                        isTopCard: index == 0 && !isExpanded,
                        showFullContent: isExpanded || index == 0,
                        stackPosition: index,
                        stackTotal: messages.count
                    )
                    .frame(height: cardHeight)
                    .padding(.horizontal, 16)
                    .offset(y: cardOffset(for: index))
                    .rotationEffect(
                        .degrees(isExpanded ? 0 : Self.rotations[index % Self.rotations.count]),
                        anchor: .center
                    )
                    .zIndex(Double(messages.count - index))
                    // Only the top card is tappable when collapsed
                    .allowsHitTesting(isExpanded || index == 0)
                    .onTapGesture {
                        if messages.count == 1 || isExpanded {
                            // Tap card → NFC scan → open letter
                            tappedMessageId = message.id
                            onTapMessage(message)
                        } else {
                            // Tap collapsed stack → fan out
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isExpanded = true
                            }
                        }
                    }
                }
            }
            .frame(height: isExpanded ? expandedHeight : collapsedHeight, alignment: .top)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isExpanded)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: tappedMessageId)

            if messages.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isExpanded ? "chevron.compact.up" : "chevron.compact.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isExpanded ? "Collapse" : "\(messages.count) sealed · tap to fan out")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardOffset(for index: Int) -> CGFloat {
        if isExpanded {
            return CGFloat(index) * (cardHeight + expandedSpacing)
        } else {
            return CGFloat(index) * collapsedPeek
        }
    }
}

// MARK: - Wax Seal

private struct WaxSeal: View {
    let isAlive: Bool
    @State private var glowing = false

    // Rich wax colors — deeper than the accent for realism
    private let waxDark = Color(red: 0.58, green: 0.28, blue: 0.18)
    private let waxMid = Color(red: 0.72, green: 0.38, blue: 0.24)
    private let waxLight = Color(red: 0.82, green: 0.48, blue: 0.32)

    var body: some View {
        ZStack {
            // Warm glow behind seal (breathing)
            Circle()
                .fill(PidgnTheme.accent.opacity(glowing ? 0.18 : 0.06))
                .frame(width: 62, height: 62)
                .blur(radius: 10)

            // Outer wax ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [waxMid, waxDark],
                        center: .center,
                        startRadius: 4,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)

            // Inner wax face — slightly off-center highlight for dimension
            Circle()
                .fill(
                    RadialGradient(
                        colors: [waxLight, waxMid],
                        center: UnitPoint(x: 0.38, y: 0.35),
                        startRadius: 0,
                        endRadius: 16
                    )
                )
                .frame(width: 38, height: 38)

            // Pidgn bird — embossed into the wax
            Image(systemName: "bird.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: waxDark.opacity(0.5), radius: 1, y: 1)
        }
        .shadow(color: waxDark.opacity(0.35), radius: 8, y: 4)
        .scaleEffect(glowing ? 1.04 : 1.0)
        .animation(
            isAlive
                ? .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
                : .default,
            value: glowing
        )
        .onAppear {
            if isAlive { glowing = true }
        }
    }
}

// MARK: - Sealed Letter Card

private struct SealedLetterCard: View {
    let message: APIService.MailMessage
    let isTopCard: Bool
    let showFullContent: Bool
    let stackPosition: Int
    let stackTotal: Int

    // Warm ink color for text
    private let ink = Color(red: 0.22, green: 0.17, blue: 0.13)
    private let inkLight = Color(red: 0.50, green: 0.44, blue: 0.38)

    private static let sealedPhrases = [
        "Sealed with care — tap your magnet to open",
        "A letter awaits your touch...",
        "Someone is thinking of you",
        "Words waiting to take flight",
        "Sealed tight — only the magnet knows",
    ]

    private var sealedPhrase: String {
        let index = abs(message.id.hashValue) % Self.sealedPhrases.count
        return Self.sealedPhrases[index]
    }

    // Paper gradient — warm parchment with subtle top-to-bottom warmth
    private var paperGradient: some ShapeStyle {
        let darken = Double(stackPosition) * 0.012
        return LinearGradient(
            colors: [
                Color(red: 0.975 - darken, green: 0.945 - darken, blue: 0.905 - darken),
                Color(red: 0.950 - darken, green: 0.918 - darken, blue: 0.872 - darken),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Edge highlight — catches light like real paper
    private var edgeGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // === Peek zone (always visible in stack) ===
            HStack(spacing: 14) {
                // The wax seal — Pidgn's mark
                WaxSeal(isAlive: isTopCard)

                VStack(alignment: .leading, spacing: 3) {
                    Text(message.fromDisplayName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)

                    if let sentAt = message.sentAt {
                        Text(relativeDate(sentAt))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(inkLight.opacity(0.7))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // === Full content (hidden when behind other cards) ===
            if showFullContent {
                Spacer(minLength: 0)

                // Ornamental divider — classic stationery detail
                HStack(spacing: 0) {
                    Spacer()
                    OrnamentalDivider()
                        .frame(width: 120)
                    Spacer()
                }
                .padding(.bottom, 8)

                // Sealed phrase + NFC hint
                VStack(spacing: 6) {
                    Text(sealedPhrase)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(inkLight.opacity(0.45))

                    HStack(spacing: 5) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 9))
                        Text("Tap to scan your magnet")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(PidgnTheme.accent.opacity(0.45))
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(paperGradient)
        )
        .overlay(
            // Glass edge — light catching the paper edge
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(edgeGradient, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // Layered shadows: tight shadow for edge + diffuse warm glow
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .shadow(color: PidgnTheme.accent.opacity(0.10 + Double(stackPosition) * 0.02), radius: 16, y: 8)
    }

    private func relativeDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: iso)
        }() else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Ornamental Divider

private struct OrnamentalDivider: View {
    private let lineColor = Color(red: 0.50, green: 0.44, blue: 0.38).opacity(0.12)
    private let dotColor = PidgnTheme.accent.opacity(0.3)

    var body: some View {
        HStack(spacing: 0) {
            // Left flourish
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0), lineColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            // Center diamond
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(dotColor)
                .padding(.horizontal, 8)

            // Right flourish
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [lineColor, lineColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
        }
    }
}

// MARK: - Opened Letter Card

private struct OpenedLetterCard: View {
    let message: APIService.MailMessage

    private let ink = Color(red: 0.22, green: 0.17, blue: 0.13)

    private var typeIcon: String {
        switch message.type {
        case "photo": return "photo"
        case "voice": return "waveform"
        default: return "envelope.open"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Sender initial — warm tinted avatar
            Text(String(message.fromDisplayName.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    PidgnTheme.accent.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                // Name + time on same baseline
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.fromDisplayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    if let sentAt = message.sentAt {
                        Text(relativeDate(sentAt))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }

                Text(preview)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()

            // Checkmark — letter has been read
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PidgnTheme.accent.opacity(0.5))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PidgnTheme.sand.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PidgnTheme.sand.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var preview: String {
        switch message.type {
        case "photo": return message.content.isEmpty ? "A photograph" : message.content
        case "voice": return "A voice note"
        default: return message.content
        }
    }

    private func relativeDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: iso)
        }() else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    MailboxView()
        .environment(AuthService())
}
