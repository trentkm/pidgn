//
//  MailboxView.swift
//  Pidgn
//
//  The roost — where letters land.
//  Sealed letters stack like Apple Wallet passes.

import SwiftUI

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
                    LetterStack(messages: sealedMessages)
                        .padding(.bottom, 24)
                }

                // Opened letters
                if !openedMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Opened")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        ForEach(openedMessages) { message in
                            NavigationLink(destination: MessageDetailView(message: message)) {
                                OpenedLetterRow(message: message)
                            }
                            .buttonStyle(.plain)
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                messages.append(contentsOf: response.messages)
            }
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
    @State private var isExpanded = false

    // Layout constants
    private let cardHeight: CGFloat = 120
    private let collapsedPeek: CGFloat = 52   // how much of each hidden card peeks out
    private let expandedSpacing: CGFloat = 14  // gap between cards when fanned out

    private var collapsedHeight: CGFloat {
        if messages.count <= 1 { return cardHeight }
        return cardHeight + CGFloat(messages.count - 1) * collapsedPeek
    }

    private var expandedHeight: CGFloat {
        CGFloat(messages.count) * cardHeight + CGFloat(messages.count - 1) * expandedSpacing
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                SealedLetterCard(
                    message: message,
                    isTopCard: index == 0 && !isExpanded,
                    showFullContent: isExpanded || index == 0
                )
                .frame(height: cardHeight)
                .padding(.horizontal, 16)
                .offset(y: cardOffset(for: index))
                .zIndex(Double(messages.count - index))
                .shadow(
                    color: .black.opacity(shadowOpacity(for: index)),
                    radius: isExpanded ? 8 : 4 + CGFloat(index) * 2,
                    y: isExpanded ? 4 : 2
                )
            }
        }
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            guard messages.count > 1 else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                isExpanded.toggle()
            }
        }
        // Collapse hint
        .overlay(alignment: .bottom) {
            if messages.count > 1 {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.compact.up" : "chevron.compact.down")
                        .font(.system(size: 14, weight: .medium))
                    Text(isExpanded ? "Collapse" : "Tap to see all")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
                .offset(y: 24)
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

    private func shadowOpacity(for index: Int) -> Double {
        if isExpanded { return 0.06 }
        // Deeper cards get slightly more shadow for depth
        return 0.04 + Double(index) * 0.02
    }
}

// MARK: - Sealed Letter Card

private struct SealedLetterCard: View {
    let message: APIService.MailMessage
    let isTopCard: Bool
    let showFullContent: Bool
    @State private var isBreathing = false

    private static let sealedPhrases = [
        "Sealed with care — tap your magnet",
        "A letter awaits...",
        "Someone's thinking of you",
        "Sealed tight — only the magnet knows",
        "Waiting to be opened",
    ]

    private var sealedPhrase: String {
        let index = abs(message.id.hashValue) % Self.sealedPhrases.count
        return Self.sealedPhrases[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row — always visible (peek zone)
            HStack(spacing: 12) {
                // Sender initial
                Text(String(message.fromDisplayName.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(PidgnTheme.accent, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(message.fromDisplayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.15))

                    if let sentAt = message.sentAt {
                        Text(relativeDate(sentAt))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color(red: 0.6, green: 0.55, blue: 0.48))
                    }
                }

                Spacer()

                // Breathing seal on top card
                Image(systemName: "seal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PidgnTheme.accent)
                    .scaleEffect(isTopCard && isBreathing ? 1.1 : 1.0)
                    .opacity(isTopCard && isBreathing ? 1.0 : 0.65)
                    .animation(
                        isTopCard
                            ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                            : .default,
                        value: isBreathing
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Bottom content — sealed phrase (visible when card is fully shown)
            if showFullContent {
                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text(sealedPhrase)
                        .font(.system(size: 12, design: .rounded))
                        .italic()
                }
                .foregroundStyle(PidgnTheme.accent.opacity(0.55))
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PidgnTheme.sand, in: RoundedRectangle(cornerRadius: 14))
        .onAppear { isBreathing = true }
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

// MARK: - Opened Letter Row

private struct OpenedLetterRow: View {
    let message: APIService.MailMessage

    private var typeIcon: String {
        switch message.type {
        case "photo": return "photo"
        case "voice": return "waveform"
        default: return "envelope.open"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(message.fromDisplayName.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemFill), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(message.fromDisplayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)

                Text(preview)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let sentAt = message.sentAt {
                    Text(relativeDate(sentAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: typeIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var preview: String {
        switch message.type {
        case "photo": return message.content.isEmpty ? "Photo" : message.content
        case "voice": return "Voice note"
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
