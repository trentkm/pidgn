//
//  MainTabView.swift
//  Pidgn
//
//  Tab-based home screen with Mailbox, Contacts, and Settings tabs.

import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) var authService
    @Binding var shouldOpenUnread: Bool

    var body: some View {
        TabView {
            MailboxView(shouldOpenUnread: shouldOpenUnread)
                .tabItem {
                    Label("Roost", systemImage: "envelope.fill")
                }

            ContactsView()
                .tabItem {
                    Label("Flock", systemImage: "bird.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Nest", systemImage: "house.fill")
                }
        }
    }
}

#Preview {
    MainTabView(shouldOpenUnread: .constant(false))
        .environment(AuthService())
}
