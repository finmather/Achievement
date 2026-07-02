import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Imperative haptics for moments `.sensoryFeedback` can't express well
/// (celebrations, refresh completion). Prepared generators, one call site.
enum Haptics {
    static func lightTap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// The "perfect game" moment: a quick double pulse, soft then firm.
    static func celebrate() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
        #endif
    }
}
