import SwiftUI
import AchievementCore

/// Circular avatar: Steam avatar when available, otherwise initials on a
/// per-person gradient (stable hue derived from the SteamID).
struct AvatarView: View {
    let profile: PlayerProfile
    var size: CGFloat = 44
    /// Profile header: a slowly rotating aurora ring around the avatar.
    var showsAuroraRing: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let url = profile.avatarFullURL ?? profile.avatarSmallURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        .overlay {
            if showsAuroraRing {
                auroraRing
            }
        }
        .accessibilityLabel(profile.personaName)
    }

    private var auroraRing: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let angle = reduceMotion
                ? 0.0
                : context.date.timeIntervalSinceReferenceDate * 18
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Theme.accent, Theme.accentTeal, Theme.accent.opacity(0.15), Theme.accent],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .rotationEffect(.degrees(angle))
                .padding(-7)
        }
    }

    private var initials: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.55, brightness: 0.85),
                    Color(hue: hue + 0.06, saturation: 0.65, brightness: 0.6),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(profile.personaName.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var hue: Double {
        // Constrained to the aurora band (indigo → teal) so generated
        // avatars never fight the palette.
        0.52 + Double(profile.id.rawValue % 240) / 1000
    }
}
