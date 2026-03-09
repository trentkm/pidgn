//
//  ContactsView.swift
//  Pidgn
//
//  Your flock — the households you're connected with.
//  Dark card-based layout with enriched contact profiles.

import SwiftUI

struct ContactsView: View {
    @Environment(AuthService.self) var authService
    @State private var contacts: [APIService.ContactEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddConnection = false
    @State private var expandedCard: String?

    private let bgColor = Color(red: 0.07, green: 0.06, blue: 0.05)
    private let cardBg = Color(red: 0.99, green: 0.96, blue: 0.93)

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var acceptedContacts: [APIService.ContactEntry] {
        contacts.filter { $0.status == "accepted" }
    }

    private var incomingRequests: [APIService.ContactEntry] {
        contacts.filter { $0.status == "pending" && $0.direction == "incoming" }
    }

    private var outgoingRequests: [APIService.ContactEntry] {
        contacts.filter { $0.status == "pending" && $0.direction == "outgoing" }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if isLoading && contacts.isEmpty {
                loadingState
            } else if let error = errorMessage, contacts.isEmpty {
                errorState(error)
            } else if contacts.isEmpty {
                emptyState
            } else {
                contactsList
            }
        }
        .navigationTitle("Flock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddConnection = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PidgnTheme.accent.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                            .foregroundStyle(PidgnTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddConnection) {
            NavigationStack {
                AddConnectionView()
            }
            .presentationDetents([.medium])
        }
        .refreshable { await fetchContacts() }
        .task { await fetchContacts() }
        .onChange(of: showAddConnection) { _, isShowing in
            if !isShowing { Task { await fetchContacts() } }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bird.fill")
                .font(.system(size: 32))
                .foregroundStyle(PidgnTheme.accent)
                .symbolEffect(.pulse)
            Text("Gathering your flock...")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bird")
                .font(.system(size: 32))
                .foregroundStyle(Color.white.opacity(0.2))
            Text("Couldn't find the flock")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
            Text(error)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.3))
            Button("Try Again") {
                Task { await fetchContacts() }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(bgColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(PidgnTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PidgnTheme.accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "bird.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(PidgnTheme.accent.opacity(0.4))
            }

            VStack(spacing: 6) {
                Text("No flock yet")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(cardBg)
                Text("Connect with another household\nto start sending letters.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddConnection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Grow Your Flock")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(bgColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(PidgnTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Incoming requests
                if !incomingRequests.isEmpty {
                    requestSection(
                        title: "Knocking at the Door",
                        icon: "bell.fill",
                        contacts: incomingRequests,
                        isIncoming: true
                    )
                }

                // Accepted contacts
                if !acceptedContacts.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(acceptedContacts) { contact in
                            FlockCard(
                                contact: contact,
                                isExpanded: expandedCard == contact.id,
                                onTap: {
                                    withAnimation(.spring(duration: 0.35)) {
                                        expandedCard = expandedCard == contact.id ? nil : contact.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                // Outgoing requests
                if !outgoingRequests.isEmpty {
                    requestSection(
                        title: "On the Wing",
                        icon: "paperplane.fill",
                        contacts: outgoingRequests,
                        isIncoming: false
                    )
                }

                // Invite CTA
                inviteCTA
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Flock")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(cardBg)

                Text("\(acceptedContacts.count) \(acceptedContacts.count == 1 ? "connection" : "connections")")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private func requestSection(title: String, icon: String, contacts: [APIService.ContactEntry], isIncoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(PidgnTheme.accent)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .padding(.horizontal, 24)

            ForEach(contacts) { contact in
                requestCard(contact: contact, isIncoming: isIncoming)
            }
        }
        .padding(.top, 20)
    }

    private func requestCard(contact: APIService.ContactEntry, isIncoming: Bool) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PidgnTheme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(contact.householdName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PidgnTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.householdName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(cardBg)
                Text(isIncoming ? "Wants to join your flock" : "Waiting for a response...")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .italic(!isIncoming)
            }

            Spacer()

            if isIncoming {
                Button {
                    Task { await acceptRequest(fromHouseholdId: contact.householdId) }
                } label: {
                    Text("Welcome In")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PidgnTheme.sage, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(cardBg.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private var inviteCTA: some View {
        VStack(spacing: 8) {
            // Divider ornament
            HStack(spacing: 10) {
                Rectangle().fill(Color.white.opacity(0.05)).frame(width: 40, height: 1)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.1))
                Rectangle().fill(Color.white.opacity(0.05)).frame(width: 40, height: 1)
            }

            Button {
                showAddConnection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Invite to the flock")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(PidgnTheme.accent)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PidgnTheme.accent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PidgnTheme.accent.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                )
            }

            Text("Share a code with someone you'd like to write to")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.12))
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Actions

    private func fetchContacts() async {
        guard let householdId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchContacts(householdId: householdId)
            contacts = response.contacts
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func acceptRequest(fromHouseholdId: String) async {
        do {
            _ = try await APIService.shared.acceptConnection(fromHouseholdId: fromHouseholdId)
            await fetchContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Flock Card

private struct FlockCard: View {
    let contact: APIService.ContactEntry
    let isExpanded: Bool
    let onTap: () -> Void

    private let cardBg = Color(red: 0.99, green: 0.96, blue: 0.93)

    private var primaryMember: APIService.ContactMember? {
        contact.members?.first
    }

    private var plumageColor: Color {
        NestColor(rawValue: primaryMember?.plumage ?? "terracotta")?.color ?? PidgnTheme.accent
    }

    private var crestEmoji: String {
        NestCrest(rawValue: primaryMember?.crest ?? "dove")?.emoji ?? "🕊️"
    }

    private var memberCount: Int {
        contact.members?.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if isExpanded {
                expandedDetail
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(isExpanded ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(cardBg.opacity(0.05), lineWidth: 1)
                )
        )
        .overlay(alignment: .leading) {
            // Plumage accent line
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(plumageColor)
                .frame(width: 3)
                .opacity(0.3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20, bottomLeadingRadius: 20,
                        bottomTrailingRadius: 0, topTrailingRadius: 0
                    )
                )
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var mainRow: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(contact.householdName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(cardBg)

                    if memberCount > 1 {
                        Text("Nest")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(plumageColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(plumageColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }

                if let bio = primaryMember?.bio, !bio.isEmpty {
                    Text("\"\(bio)\"")
                        .font(.custom("Bradley Hand", size: 14))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Quill button — visual only for now
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(plumageColor.opacity(0.1))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(plumageColor.opacity(0.15), lineWidth: 1)
                    )
                Image(systemName: "pencil.line")
                    .font(.system(size: 14))
                    .foregroundStyle(plumageColor)
            }
        }
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [plumageColor, plumageColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .shadow(color: plumageColor.opacity(0.25), radius: 8, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 2)
                )

            if memberCount > 1 {
                // Nest: show member count icon
                VStack(spacing: 0) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(memberCount)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text(crestEmoji)
                    .font(.system(size: 25))
            }
        }
    }

    // MARK: - Expanded Detail

    private var expandedDetail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.top, 16)
                .padding(.bottom, 14)

            // Letter stats
            letterStats

            // Activity bar
            activityBar

            // Last letter
            lastLetterSection

            // Members list (if nest)
            if memberCount > 1, let members = contact.members {
                membersSection(members)
            }
        }
    }

    private var letterStats: some View {
        HStack(spacing: 0) {
            statColumn(value: contact.lettersSent ?? 0, label: "Sent")
            statDivider
            statColumn(value: contact.lettersReceived ?? 0, label: "Received")
            statDivider
            statColumn(value: (contact.lettersSent ?? 0) + (contact.lettersReceived ?? 0), label: "Total")
        }
        .padding(.bottom, 14)
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(cardBg)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.2))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(width: 1, height: 28)
    }

    private var activityBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let sent = max(contact.lettersSent ?? 0, 0)
                let received = max(contact.lettersReceived ?? 0, 0)
                let total = max(sent + received, 1)

                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(plumageColor.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(sent) / CGFloat(total))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: geo.size.width * CGFloat(received) / CGFloat(total))
                }
            }
            .frame(height: 4)

            HStack {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(plumageColor.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("You sent")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
                Spacer()
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 8, height: 8)
                    Text("They sent")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }
        }
        .padding(.bottom, 14)
    }

    private var lastLetterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastAt = contact.lastLetterAt {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.15))
                    Text("Last letter: ")
                        .foregroundStyle(Color.white.opacity(0.3))
                    + Text(relativeDate(lastAt))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .font(.system(size: 12, design: .rounded))

                // Nudge if it's been a while
                if let nudge = nudgeText(lastAt) {
                    Text(nudge)
                        .font(.custom("Bradley Hand", size: 14))
                        .foregroundStyle(plumageColor.opacity(0.6))
                        .italic()
                        .padding(.top, 2)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.15))
                    Text("No letters exchanged yet")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func membersSection(_ members: [APIService.ContactMember]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Members")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.2))
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 8) {
                ForEach(members, id: \.displayName) { member in
                    HStack(spacing: 6) {
                        let memberPlumage = NestColor(rawValue: member.plumage ?? "")?.color ?? plumageColor
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(memberPlumage.opacity(0.6))
                                .frame(width: 22, height: 22)
                            if let emoji = NestCrest(rawValue: member.crest ?? "")?.emoji {
                                Text(emoji)
                                    .font(.system(size: 10))
                            } else {
                                Text(String(member.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text(member.displayName)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func relativeDate(_ isoString: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: isoString) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: isoString)
        }() else { return "" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func nudgeText(_ isoString: String) -> String? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: isoString) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: isoString)
        }() else { return nil }

        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days >= 14 {
            return "It's been a while — send a letter?"
        } else if days >= 7 {
            return "A week since the last letter..."
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        ContactsView()
            .environment(AuthService())
    }
}
