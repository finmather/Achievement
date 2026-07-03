import SwiftUI

/// Staggered entrance choreography: each element fades in and rises 14pt,
/// 50ms after the previous one. Used on every screen's first appearance so
/// content settles into place instead of popping.
private struct EntranceModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(
                    .spring(duration: 0.6, bounce: 0.2)
                    .delay(Double(index) * 0.05)
                ) {
                    shown = true
                }
            }
    }
}

extension View {
    /// - Parameter index: position in the screen's choreography (0-based).
    func entrance(_ index: Int) -> some View {
        modifier(EntranceModifier(index: index))
    }
}
