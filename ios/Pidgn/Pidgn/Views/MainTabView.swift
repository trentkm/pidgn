//
//  MainTabView.swift
//  Pidgn
//
//  Tab-based home screen with Mailbox, Contacts, and Settings tabs.

import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) var authService

    var body: some View {
        TabView {
            MailboxView()
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
    MainTabView()
        .environment(AuthService())
}
