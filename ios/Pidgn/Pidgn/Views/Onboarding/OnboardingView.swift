//
//  OnboardingView.swift
//  Pidgn
//
//  First-launch walkthrough. Warm, simple, three pages.

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        (
            "bird.fill",
            "Letters Carried\nWith Care",
            "Send notes, photos, and voice messages to the people who matter most."
        ),
        (
            "wave.3.right",
            "Your Fridge\nMagnet",
            "Every household gets a physical magnet. Letters stay sealed until someone walks over and taps."
        ),
        (
            "lock.open.fill",
            "Break the Seal",
            "No endless scrolling. Just the warmth of real mail, arriving at your fridge."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: pages[index].icon)
                            .font(.system(size: 56))
                            .foregroundStyle(PidgnTheme.accent)
                            .padding(.bottom, 8)

                        Text(pages[index].title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(pages[index].body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(PidgnTheme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            if currentPage < pages.count - 1 {
                Button("Skip") { hasCompletedOnboarding = true }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            } else {
                Spacer().frame(height: 48)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
