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
                    Label("Mailbox", systemImage: "envelope.fill")
                }

            ContactsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView(shouldOpenUnread: .constant(false))
        .environment(AuthService())
}
