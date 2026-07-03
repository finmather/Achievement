import SwiftUI

/// The app-wide press feel: a slight, springy deform with a soft haptic.
/// Scale is subtle on large surfaces so cards never feel toy-like.
struct PressableStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(duration: 0.3, bounce: 0.45), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}

extension ButtonStyle where Self == PressableStyle {
    /// For buttons and small controls.
    static var pressable: PressableStyle { PressableStyle() }
    /// For full-width cards — deform less so it reads as depth, not shrink.
    static var pressableCard: PressableStyle { PressableStyle(pressedScale: 0.985) }
}
