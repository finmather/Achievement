import SwiftUI

/// A section's ambient mood: two bloom hues, a chrome tint for small
/// accents, and an energy level. Every major section owns one, so screens
/// feel individually lit while sharing one design system.
struct SectionPalette: Equatable {
    var primary: Color
    var secondary: Color
    /// Small chrome accents (section titles, header whispers).
    var tint: Color
    /// Bloom intensity multiplier — friends runs brighter, library quieter.
    var energy: Double = 1

    /// Warm and welcoming: ember and soft rose, a fireside for the ritual.
    static let dashboard = SectionPalette(
        primary: Color(red: 0.78, green: 0.48, blue: 0.24),
        secondary: Color(red: 0.64, green: 0.32, blue: 0.40),
        tint: Color(red: 0.88, green: 0.66, blue: 0.42)
    )

    /// Neutral slate — the shelf recedes so cover art carries the color.
    static let library = SectionPalette(
        primary: Color(red: 0.42, green: 0.48, blue: 0.58),
        secondary: Color(red: 0.32, green: 0.36, blue: 0.46),
        tint: Color(red: 0.62, green: 0.70, blue: 0.80),
        energy: 0.75
    )

    /// Brighter, sociable teal-cyan.
    static let friends = SectionPalette(
        primary: Color(red: 0.14, green: 0.62, blue: 0.64),
        secondary: Color(red: 0.20, green: 0.52, blue: 0.76),
        tint: Theme.accentTeal,
        energy: 1.3
    )

    /// Calm indigo with a quiet gold ember — the trophy room.
    static let profile = SectionPalette(
        primary: Color(red: 0.32, green: 0.36, blue: 0.64),
        secondary: Color(red: 0.62, green: 0.48, blue: 0.22),
        tint: Color(red: 0.62, green: 0.65, blue: 0.90)
    )

    /// First impressions: a touch more color than any single section.
    static let onboarding = SectionPalette(
        primary: Color(red: 0.46, green: 0.40, blue: 0.76),
        secondary: Color(red: 0.16, green: 0.56, blue: 0.60),
        tint: Theme.accent,
        energy: 1.25
    )

    /// The unlock moment — gold enters the field.
    static let celebration = SectionPalette(
        primary: Color(red: 0.72, green: 0.54, blue: 0.20),
        secondary: Color(red: 0.44, green: 0.34, blue: 0.70),
        tint: Theme.gold,
        energy: 1.6
    )

    /// Art-derived, for game detail pages.
    static func art(glow: Color, deep: Color) -> SectionPalette {
        SectionPalette(primary: glow, secondary: deep, tint: glow, energy: 1.1)
    }
}

/// Layered ambient light, not a gradient poster: a near-neutral base, two
/// large low-saturation radial blooms that drift glacially, a small high
/// accent, and a quiet luminance gradient for depth. The light warms up
/// briefly whenever a screen appears, so tab changes feel like walking into
/// a differently lit room rather than swapping wallpaper.
struct AmbientBackground: View {
    var palette: SectionPalette = .dashboard

    @State private var lit = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                layers(t: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 12)) { context in
                    layers(t: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            lit = false
            withAnimation(.easeOut(duration: 0.7)) { lit = true }
        }
    }

    private func layers(t: TimeInterval) -> some View {
        let dark = scheme == .dark
        let base = dark
            ? Color(red: 0.047, green: 0.051, blue: 0.071)
            : Color(red: 0.957, green: 0.951, blue: 0.941)
        let energy = palette.energy * (lit ? 1 : 0.55)
        let primaryOpacity = (dark ? 0.17 : 0.22) * energy
        let secondaryOpacity = (dark ? 0.12 : 0.16) * energy

        return ZStack {
            base

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                ZStack {
                    bloom(palette.primary, opacity: primaryOpacity, radius: w * 1.0)
                        .position(
                            x: w * (0.20 + 0.10 * sin(t * 0.050)),
                            y: h * (0.16 + 0.06 * cos(t * 0.041))
                        )
                    bloom(palette.secondary, opacity: secondaryOpacity, radius: w * 1.15)
                        .position(
                            x: w * (0.88 + 0.08 * sin(t * 0.037 + 2.1)),
                            y: h * (0.74 + 0.07 * sin(t * 0.045 + 4.2))
                        )
                    // A small high key-light keeps the top from going flat.
                    bloom(palette.primary, opacity: secondaryOpacity * 0.55, radius: w * 0.45)
                        .position(
                            x: w * (0.78 + 0.05 * cos(t * 0.06 + 1.0)),
                            y: h * (0.04 + 0.03 * sin(t * 0.052 + 0.6))
                        )
                }
            }

            // Depth: faint top light, gentle bottom settle.
            LinearGradient(
                colors: dark
                    ? [Color.white.opacity(0.035), .clear, Color.black.opacity(0.26)]
                    : [Color.white.opacity(0.55), .clear, Color.black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func bloom(_ color: Color, opacity: Double, radius: CGFloat) -> some View {
        RadialGradient(
            colors: [
                color.opacity(opacity),
                color.opacity(opacity * 0.38),
                .clear,
            ],
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
        .frame(width: radius * 2, height: radius * 2)
    }
}

#Preview("Moods") {
    TabView {
        AmbientBackground(palette: .dashboard).tabItem { Text("Dash") }
        AmbientBackground(palette: .library).tabItem { Text("Library") }
        AmbientBackground(palette: .friends).tabItem { Text("Friends") }
        AmbientBackground(palette: .profile).tabItem { Text("Profile") }
    }
    .preferredColorScheme(.dark)
}
