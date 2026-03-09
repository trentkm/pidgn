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
    @State private var senderFilter: String?

    @State var shouldOpenUnread: Bool = false

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var sealedMessages: [APIService.MailMessage] {
        messages.filter { !$0.isOpened }
    }

    private var openedMessages: [APIService.MailMessage] {
        let opened = messages.filter { $0.isOpened }
        if let filter = senderFilter {
            return opened.filter { $0.fromDisplayName == filter }
        }
        return opened
    }

    private var allOpenedMessages: [APIService.MailMessage] {
        messages.filter { $0.isOpened }
    }

    /// Unique senders from opened mail, ordered by most recent letter
    private var uniqueSenders: [SenderInfo] {
        var seen = Set<String>()
        var result: [SenderInfo] = []
        for msg in allOpenedMessages {
            if !seen.contains(msg.fromDisplayName) {
                seen.insert(msg.fromDisplayName)
                let count = allOpenedMessages.filter { $0.fromDisplayName == msg.fromDisplayName }.count
                let plumageColor = NestColor(rawValue: msg.fromPlumage ?? "")?.color
                    ?? senderColor(for: msg.fromDisplayName)
                result.append(SenderInfo(
                    name: msg.fromDisplayName,
                    count: count,
                    color: plumageColor,
                    avatarUrl: msg.fromAvatarUrl,
                    crest: msg.fromCrest,
                    plumage: msg.fromPlumage
                ))
            }
        }
        return result
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
                if !allOpenedMessages.isEmpty {
                    openedSection
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

    // MARK: - Opened Section

    private var openedSection: some View {
        VStack(spacing: 0) {
            // "read letters" divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                Text("read letters")
                    .font(.custom("Bradley Hand", size: 16))
                    .foregroundStyle(.white.opacity(0.2))
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            // Avatar filter row
            if uniqueSenders.count > 1 {
                avatarFilterRow
                    .padding(.bottom, 6)
            }

            // Active filter label
            if let filter = senderFilter {
                HStack {
                    Text("letters from \(filter)...")
                        .font(.custom("Bradley Hand", size: 15))
                        .foregroundStyle(.white.opacity(0.2))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Letter cards
            if openedMessages.isEmpty {
                // Empty filter state
                VStack(spacing: 12) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("No letters from \(senderFilter ?? "") yet")
                        .font(.custom("Bradley Hand", size: 18))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Perhaps a quill is in order?")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(openedMessages.enumerated()), id: \.element.id) { index, message in
                    NavigationLink(destination: MessageDetailView(message: message)) {
                        ScatteredLetterCard(message: message, index: index)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 7)
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Avatar Filter Row

    private var avatarFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(uniqueSenders) { sender in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if senderFilter == sender.name {
                                senderFilter = nil
                            } else {
                                senderFilter = sender.name
                            }
                        }
                    } label: {
                        let isActive = senderFilter == sender.name
                        let dimmed = senderFilter != nil && !isActive

                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                // Avatar
                                AvatarView(
                                    avatarUrl: sender.avatarUrl,
                                    plumage: sender.plumage,
                                    crest: sender.crest,
                                    displayName: sender.name,
                                    size: 44,
                                    cornerRadius: 13
                                )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(isActive ? .white.opacity(0.25) : .clear, lineWidth: 2)
                                    )
                                    .shadow(
                                        color: isActive ? sender.color.opacity(0.4) : .black.opacity(0.15),
                                        radius: isActive ? 8 : 3,
                                        y: isActive ? 4 : 2
                                    )

                                // Count badge
                                Text("\(sender.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(isActive ? Color(red: 0.1, green: 0.08, blue: 0.06) : .white.opacity(0.6))
                                    .frame(width: 18, height: 18)
                                    .background(
                                        Circle()
                                            .fill(isActive ? Color(red: 0.99, green: 0.96, blue: 0.93) : .white.opacity(0.15))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.07, green: 0.06, blue: 0.04), lineWidth: 2)
                                    )
                                    .offset(x: 4, y: -4)
                            }

                            Text(sender.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(isActive ? .white.opacity(0.7) : .white.opacity(0.3))
                        }
                        .opacity(dimmed ? 0.35 : 1)
                        .offset(y: isActive ? -2 : 0)
                        .animation(.easeInOut(duration: 0.25), value: isActive)
                    }
                    .buttonStyle(.plain)
                }

                // Clear filter button
                if senderFilter != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            senderFilter = nil
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(.white.opacity(0.06))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(.white.opacity(0.08), lineWidth: 1)
                                    )
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Text("All")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    private struct SenderInfo: Identifiable {
        let name: String
        let count: Int
        let color: Color
        let avatarUrl: String?
        let crest: String?
        let plumage: String?
        var id: String { name }
    }

    /// Generate a consistent color for a sender name
    private func senderColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.76, green: 0.48, blue: 0.35), // terracotta
            Color(red: 0.48, green: 0.55, blue: 0.44), // sage
            Color(red: 0.44, green: 0.50, blue: 0.66), // slate blue
            Color(red: 0.66, green: 0.48, blue: 0.62), // mauve
            Color(red: 0.55, green: 0.62, blue: 0.50), // moss
            Color(red: 0.60, green: 0.45, blue: 0.42), // clay
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
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

        do {
            try await NFCService.shared.scanTag()
        } catch {
            let nfcError = error as? NFCReaderError
            if nfcError?.code == .readerSessionInvalidationErrorUserCanceled { return }
            if let nfcErr = error as? NFCError, nfcErr == .sessionBusy { return }
            errorMessage = error.localizedDescription
            return
        }

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

// MARK: - Scattered Letter Card (Opened)

private struct ScatteredLetterCard: View {
    let message: APIService.MailMessage
    let index: Int

    private var mood: Stationery {
        Stationery(rawValue: message.stationery ?? "parchment") ?? .parchment
    }

    // Subtle scatter for a natural "pile of letters" feel
    private static let rotations: [Double] = [-1.1, 0.7, -0.4, 1.0, -0.8, 0.5, -0.3, 0.9]
    private static let offsets: [CGFloat] = [-2, 3, -1, 2, -3, 1, -2, 3]

    private var rotation: Double {
        Self.rotations[index % Self.rotations.count]
    }

    private var xOffset: CGFloat {
        Self.offsets[index % Self.offsets.count]
    }

    private var preview: String {
        switch message.type {
        case "photo": return message.content.isEmpty ? "A photograph" : message.content
        case "voice": return "A voice note"
        default: return message.content
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Sender avatar
            AvatarView(
                avatarUrl: message.fromAvatarUrl,
                plumage: message.fromPlumage,
                crest: message.fromCrest,
                displayName: message.fromDisplayName,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.fromDisplayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    if let sentAt = message.sentAt {
                        Text(relativeDate(sentAt))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.2))
                            .italic()
                    }
                }

                Text("\"\(preview)\"")
                    .font(.custom("Bradley Hand", size: 16))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }

            Spacer()

            // Broken seal icon
            BrokenSealIcon(color: mood.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            ZStack {
                // Stationery tinted background
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                mood.accentColor.opacity(0.08),
                                mood.accentColor.opacity(0.03),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Faint ruled lines
                VStack(spacing: 18) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(mood.accentColor.opacity(0.04))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 52)
                .padding(.top, 10)
            }
        )
        .overlay(alignment: .leading) {
            // Left accent border
            RoundedRectangle(cornerRadius: 2)
                .fill(mood.accentColor.opacity(0.5))
                .frame(width: 3)
                .padding(.vertical, 6)
        }
        .overlay(alignment: .topTrailing) {
            // Corner fold
            CornerFold(color: mood.accentColor.opacity(0.15))
                .frame(width: 18, height: 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .rotationEffect(.degrees(rotation), anchor: .center)
        .offset(x: xOffset)
    }

    private func senderColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.76, green: 0.48, blue: 0.35),
            Color(red: 0.48, green: 0.55, blue: 0.44),
            Color(red: 0.44, green: 0.50, blue: 0.66),
            Color(red: 0.66, green: 0.48, blue: 0.62),
            Color(red: 0.55, green: 0.62, blue: 0.50),
            Color(red: 0.60, green: 0.45, blue: 0.42),
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
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

// MARK: - Broken Seal Icon

private struct BrokenSealIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            // Cracked seal burst
            Image(systemName: "seal")
                .font(.system(size: 16))
                .foregroundStyle(color.opacity(0.3))

            // Crack line
            Path { p in
                p.move(to: CGPoint(x: 7, y: 5))
                p.addLine(to: CGPoint(x: 11, y: 13))
            }
            .stroke(color.opacity(0.2), lineWidth: 0.8)
            .frame(width: 18, height: 18)
        }
    }
}

// MARK: - Corner Fold

private struct CornerFold: Shape {
    let color: Color

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.closeSubpath()
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
                    .allowsHitTesting(isExpanded || index == 0)
                    .onTapGesture {
                        if messages.count == 1 || isExpanded {
                            tappedMessageId = message.id
                            onTapMessage(message)
                        } else {
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

    private let waxDark = Color(red: 0.58, green: 0.28, blue: 0.18)
    private let waxMid = Color(red: 0.72, green: 0.38, blue: 0.24)
    private let waxLight = Color(red: 0.82, green: 0.48, blue: 0.32)

    var body: some View {
        ZStack {
            Circle()
                .fill(PidgnTheme.accent.opacity(glowing ? 0.18 : 0.06))
                .frame(width: 62, height: 62)
                .blur(radius: 10)

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
            HStack(spacing: 14) {
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

            if showFullContent {
                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    Spacer()
                    OrnamentalDivider()
                        .frame(width: 120)
                    Spacer()
                }
                .padding(.bottom, 8)

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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(edgeGradient, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0), lineColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(dotColor)
                .padding(.horizontal, 8)

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

#Preview {
    MailboxView()
        .environment(AuthService())
}
