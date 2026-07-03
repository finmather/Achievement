import SwiftUI

/// The living canvas behind every screen: a slowly drifting mesh of deep
/// dusk color (dark) or soft dawn mist (light). Motion is deliberately
/// glacial — the app should feel alive at rest, never busy. Scroll position
/// nudges the field so the world responds to the user's hand.
struct AuroraBackground: View {
    enum Intensity {
        /// Standard screen backdrop.
        case ambient
        /// Onboarding and profile header — richer color.
        case hero
        /// Unlock celebrations — brightest, with gold in the field.
        case celebration
    }

    var intensity: Intensity = .ambient
    var scrollOffset: CGFloat = 0

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                mesh(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                    mesh(time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func mesh(time t: TimeInterval) -> some View {
        // Scroll gently compresses the field upward; clamped so edge points
        // never leave their edges.
        let scroll = Float(max(-0.1, min(0.12, scrollOffset * 0.0002)))
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, wave(t, speed: 0.07, base: 0.42, amp: 0.05) - scroll],
            [wave(t, speed: 0.05, base: 0.48, amp: 0.13, phase: 1.3),
             wave(t, speed: 0.06, base: 0.52, amp: 0.11, phase: 2.1) - scroll],
            [1, wave(t, speed: 0.055, base: 0.58, amp: 0.06, phase: 4.0) - scroll],
            [0, 1], [wave(t, speed: 0.045, base: 0.5, amp: 0.09, phase: 5.2), 1], [1, 1],
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: palette)
    }

    private func wave(
        _ t: TimeInterval, speed: Double, base: Float, amp: Float, phase: Double = 0
    ) -> Float {
        base + amp * Float(sin(t * speed + phase))
    }

    /// Nine colors, row-major top→bottom. Dark is a dusk sky; light is dawn
    /// mist. Gold only ever enters the field during celebration.
    private var palette: [Color] {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
            Color(red: r, green: g, blue: b)
        }
        let lift: Double = switch intensity {
        case .ambient: 1.0
        case .hero: 1.3
        case .celebration: 1.55
        }
        func mid(_ r: Double, _ g: Double, _ b: Double) -> Color {
            rgb(min(1, r * lift), min(1, g * lift), min(1, b * lift))
        }
        let ember: Color = intensity == .celebration
            ? (scheme == .dark ? rgb(0.42, 0.30, 0.10) : rgb(0.99, 0.88, 0.68))
            : (scheme == .dark ? mid(0.05, 0.28, 0.32) : mid(0.85, 0.94, 0.95))

        if scheme == .dark {
            return [
                rgb(0.045, 0.04, 0.11), rgb(0.07, 0.05, 0.16), rgb(0.05, 0.06, 0.14),
                mid(0.15, 0.11, 0.36), mid(0.26, 0.16, 0.52), ember,
                rgb(0.03, 0.03, 0.08), rgb(0.09, 0.06, 0.20), rgb(0.04, 0.09, 0.11),
            ]
        }
        return [
            rgb(0.97, 0.96, 0.995), rgb(0.94, 0.93, 0.99), rgb(0.96, 0.95, 0.98),
            mid(0.89, 0.86, 0.985), mid(0.965, 0.885, 0.845), ember,
            rgb(0.93, 0.92, 0.97), rgb(0.955, 0.90, 0.92), rgb(0.90, 0.94, 0.96),
        ]
    }
}

extension View {
    /// Feeds a ScrollView's offset into an `AuroraBackground` binding so the
    /// backdrop breathes with the scroll.
    func trackScrollOffset(into offset: Binding<CGFloat>) -> some View {
        onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, new in
            offset.wrappedValue = new
        }
    }
}

#Preview("Aurora dark") {
    AuroraBackground(intensity: .hero)
        .preferredColorScheme(.dark)
}

#Preview("Aurora light") {
    AuroraBackground()
        .preferredColorScheme(.light)
}
