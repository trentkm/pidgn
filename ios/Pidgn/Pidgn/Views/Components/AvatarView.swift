//
//  AvatarView.swift
//  Pidgn
//
//  Reusable avatar: shows photo if available, falls back to crest emoji,
//  then to initials. Plumage color is always the background.

import SwiftUI

struct AvatarView: View {
    let avatarUrl: String?
    let plumage: String?
    let crest: String?
    let displayName: String
    let size: CGFloat
    var cornerRadius: CGFloat?

    private var plumageColor: Color {
        NestColor(rawValue: plumage ?? "")?.color ?? PidgnTheme.accent
    }

    private var crestEmoji: String? {
        NestCrest(rawValue: crest ?? "")?.emoji
    }

    private var radius: CGFloat {
        cornerRadius ?? (size * 0.3)
    }

    private var emojiSize: CGFloat {
        size * 0.5
    }

    private var initialSize: CGFloat {
        size * 0.38
    }

    var body: some View {
        ZStack {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                // Photo avatar
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    plumageBackground
                    ProgressView()
                        .tint(.white.opacity(0.6))
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                // Plumage + crest/initials fallback
                plumageBackground
                    .overlay {
                        if let emoji = crestEmoji {
                            Text(emoji)
                                .font(.system(size: emojiSize))
                        } else {
                            Text(String(displayName.prefix(1)).uppercased())
                                .font(.system(size: initialSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
    }

    private var plumageBackground: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [plumageColor, plumageColor.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(avatarUrl: nil, plumage: "sage", crest: "owl", displayName: "Mom", size: 56)
        AvatarView(avatarUrl: nil, plumage: "plum", crest: nil, displayName: "Dad", size: 44)
        AvatarView(avatarUrl: nil, plumage: "terracotta", crest: "dove", displayName: "Sis", size: 36)
    }
    .padding()
    .background(Color(red: 0.07, green: 0.06, blue: 0.05))
}
