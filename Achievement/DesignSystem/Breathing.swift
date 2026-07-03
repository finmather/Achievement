import SwiftUI

/// Loading placeholders breathe — a slow opacity swell, calmer than a
/// shimmer sweep and consistent with the aurora's tempo.
private struct BreathingModifier: ViewModifier {
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.45 : 0.85)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

/// A placeholder blob in the app's shape language.
struct BreathingPlaceholder: View {
    enum Shape {
        case capsule
        case circle
        case blob(CGFloat)
    }

    var shape: Shape = .blob(28)

    var body: some View {
        Group {
            switch shape {
            case .capsule:
                Capsule().fill(.quaternary)
            case .circle:
                Circle().fill(.quaternary)
            case .blob(let radius):
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.quaternary)
            }
        }
        .breathing()
    }
}

extension View {
    func breathing() -> some View {
        modifier(BreathingModifier())
    }
}
