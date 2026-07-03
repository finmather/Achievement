import SwiftUI

/// Single source of truth for spatial values. Screens never hardcode
/// margins, radii, or icon sizes — value drift between screens is how a
/// design stops feeling intentional.
enum Tokens {
    /// Horizontal screen margin — every screen, no exceptions.
    static let screenMargin: CGFloat = 24
    /// Vertical rhythm between floating sections.
    static let sectionGap: CGFloat = 26
    /// Gap between sibling items (rows in a group, chips in a rail).
    static let itemGap: CGFloat = 12

    enum Radius {
        /// Glass blobs (rows, capsule-adjacent groups).
        static let blob: CGFloat = 28
        /// Cover art in grids.
        static let art: CGFloat = 26
        /// Hero art and featured covers.
        static let hero: CGFloat = 30
    }

    enum IconSize {
        /// Rail chips and inline icons.
        static let s: CGFloat = 34
        /// Row leading icons (achievements, games, friends).
        static let m: CGFloat = 46
        /// Spotlights and headers.
        static let l: CGFloat = 58
    }
}

/// The app's motion vocabulary — three springs, used everywhere.
extension Animation {
    /// Presses, chip selection, small state flips.
    static let snap = Animation.spring(duration: 0.35, bounce: 0.4)
    /// Content arriving or rearranging.
    static let settle = Animation.spring(duration: 0.6, bounce: 0.2)
    /// Rings, arcs, and other progress sweeps.
    static let sweep = Animation.spring(duration: 1.1, bounce: 0.16)
}
