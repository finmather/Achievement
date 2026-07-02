import SwiftUI
import AchievementCore

/// Circular avatar: Steam avatar when available, otherwise initials on a
/// per-person gradient (stable hue derived from the SteamID).
struct AvatarView: View {
    let profile: PlayerProfile
    var size: CGFloat = 44

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
        .accessibilityLabel(profile.personaName)
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
        Double(profile.id.rawValue % 360) / 360
    }
}
