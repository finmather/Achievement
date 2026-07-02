import SwiftUI
import AchievementCore

/// The app's visual language in one place. Calm neutrals for chrome, one
/// confident accent, and a single completion hue progression used everywhere:
/// indigo (starting) → blue (working) → teal (closing in) → gold (perfect).
/// Users learn the language once and read progress at a glance.
enum Theme {
    // MARK: - Accent & fixed colors

    static let accent = Color(red: 0.36, green: 0.42, blue: 0.96)

    static let gold = Color(red: 0.98, green: 0.75, blue: 0.24)
    static let goldDeep = Color(red: 0.93, green: 0.58, blue: 0.12)

    // MARK: - Completion language

    static func completionColors(fraction: Double, isPerfect: Bool) -> [Color] {
        if isPerfect {
            return [gold, goldDeep]
        }
        switch fraction {
        case ..<0.001:
            return [Color(white: 0.62), Color(white: 0.5)]
        case ..<0.34:
            return [Color(red: 0.48, green: 0.44, blue: 0.96),
                    Color(red: 0.36, green: 0.42, blue: 0.96)]
        case ..<0.67:
            return [Color(red: 0.30, green: 0.56, blue: 0.98),
                    Color(red: 0.22, green: 0.72, blue: 0.93)]
        default:
            return [Color(red: 0.18, green: 0.76, blue: 0.78),
                    Color(red: 0.16, green: 0.82, blue: 0.57)]
        }
    }

    static func completionGradient(fraction: Double, isPerfect: Bool = false) -> LinearGradient {
        LinearGradient(
            colors: completionColors(fraction: fraction, isPerfect: isPerfect),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Rarity language

    static func color(for rarity: Rarity) -> Color {
        switch rarity {
        case .common: Color(white: 0.55)
        case .uncommon: Color(red: 0.22, green: 0.72, blue: 0.55)
        case .rare: Color(red: 0.30, green: 0.56, blue: 0.98)
        case .veryRare: Color(red: 0.62, green: 0.42, blue: 0.98)
        case .legendary: gold
        }
    }

    // MARK: - Surfaces

    /// Cards sit on the grouped background with a hairline, not a heavy shadow.
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.11) : .white
    }
}

/// Soft two-stop wash behind every screen — quieter than a flat fill,
/// far from glassmorphism.
struct ScreenBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.05, green: 0.05, blue: 0.08), Color(red: 0.08, green: 0.08, blue: 0.11)]
                : [Color(red: 0.96, green: 0.96, blue: 0.98), Color(red: 0.93, green: 0.94, blue: 0.97)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Standard card container: soft corner radius, hairline stroke, gentle shadow.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground(scheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(scheme == .dark ? 0.08 : 0.05), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(scheme == .dark ? 0.35 : 0.06),
                radius: 14, y: 6
            )
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}
