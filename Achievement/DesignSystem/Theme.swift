import SwiftUI
import AchievementCore

/// The Aurora visual language. One completion hue progression (indigo →
/// blue → teal, gold strictly reserved for perfection), a violet–teal
/// duotone accent, and glass chips instead of card rectangles. Surfaces are
/// capsules, circles, and continuous-corner blobs floating on the aurora.
enum Theme {
    // MARK: - Accent duotone

    static let accent = Color(red: 0.47, green: 0.40, blue: 0.98)
    static let accentTeal = Color(red: 0.16, green: 0.72, blue: 0.72)

    static var accentDuotone: LinearGradient {
        LinearGradient(
            colors: [accent, accentTeal],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static let gold = Color(red: 0.98, green: 0.76, blue: 0.26)
    static let goldDeep = Color(red: 0.91, green: 0.56, blue: 0.11)

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [gold, goldDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Completion language

    static func completionColors(fraction: Double, isPerfect: Bool) -> [Color] {
        if isPerfect {
            return [gold, goldDeep]
        }
        switch fraction {
        case ..<0.001:
            return [Color(white: 0.6), Color(white: 0.45)]
        case ..<0.34:
            return [Color(red: 0.52, green: 0.44, blue: 0.99),
                    Color(red: 0.38, green: 0.40, blue: 0.97)]
        case ..<0.67:
            return [Color(red: 0.32, green: 0.55, blue: 0.99),
                    Color(red: 0.20, green: 0.72, blue: 0.94)]
        default:
            return [Color(red: 0.16, green: 0.77, blue: 0.77),
                    Color(red: 0.18, green: 0.84, blue: 0.55)]
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
        case .uncommon: Color(red: 0.22, green: 0.74, blue: 0.55)
        case .rare: Color(red: 0.32, green: 0.56, blue: 0.99)
        case .veryRare: Color(red: 0.64, green: 0.42, blue: 0.99)
        case .legendary: gold
        }
    }

    /// The halo behind celebration icons and rare unlock rows.
    static func glow(for rarity: Rarity) -> Color {
        color(for: rarity).opacity(0.55)
    }
}

// MARK: - Glass chips

/// The only surface in the app: thin material clipped to an organic shape.
/// Never a full-width rectangle — content floats, chips punctuate.
enum GlassShape {
    case capsule
    case circle
    case blob(CGFloat)

    var anyShape: AnyShape {
        switch self {
        case .capsule: AnyShape(Capsule())
        case .circle: AnyShape(Circle())
        case .blob(let radius):
            AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

private struct GlassChip: ViewModifier {
    let shape: GlassShape
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let anyShape = shape.anyShape
        // Shadow belongs to the flattened material silhouette only. Applying
        // it after the stroke overlay makes the hairline cast its own shadow
        // — a dark ring artifact at the corners.
        content
            .background {
                anyShape
                    .fill(.ultraThinMaterial)
                    .compositingGroup()
                    .shadow(
                        color: .black.opacity(scheme == .dark ? 0.32 : 0.09),
                        radius: 16, y: 8
                    )
            }
            .overlay(
                anyShape.stroke(
                    scheme == .dark
                        ? Color.white.opacity(0.13)
                        : Color.white.opacity(0.6),
                    lineWidth: 0.8
                )
            )
    }
}

extension View {
    func glassChip(_ shape: GlassShape = .capsule) -> some View {
        modifier(GlassChip(shape: shape))
    }
}
